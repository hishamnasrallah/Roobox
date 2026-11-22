-- Roobox server logic for Nakama (Lua runtime).
local nk = require("nakama")

-- Leaderboards. Courses: lowest time wins (milliseconds).
-- Round modes: highest wins (seconds survived / rounds / stages).
local BOARDS = {
  obby_land   = { sort = "asc",  min = 20000, max = 3600000 },
  sky_tower   = { sort = "asc",  min = 15000, max = 3600000 },
  lava_rising = { sort = "desc", min = 1,     max = 600 },
  color_drop  = { sort = "desc", min = 1,     max = 100 },
  obby_rush   = { sort = "desc", min = 1,     max = 100000 },
}

for id, cfg in pairs(BOARDS) do
  local ok, err = pcall(nk.leaderboard_create, id, false, cfg.sort, "best", nil, { board = id })
  if not ok then
    nk.logger_info(("leaderboard %s: %s"):format(id, tostring(err)))
  end
end

-- Basic anti-cheat: reject impossible scores and unknown boards.
local function before_write_record(context, payload)
  local board = BOARDS[payload.leaderboard_id]
  if board == nil then
    return nil
  end
  local score = tonumber(payload.record.score) or 0
  if score < board.min or score > board.max then
    nk.logger_warn(("rejected score %s on %s from %s"):format(tostring(score), payload.leaderboard_id, context.user_id or "?"))
    return nil
  end
  return payload
end
nk.register_req_before(before_write_record, "WriteLeaderboardRecord")

-- Public game servers the app can join with one tap.
local function server_list(context, payload)
  local servers = {}
  local raw = (context.env and context.env["GAME_SERVERS"]) or ""
  for entry in string.gmatch(raw, "([^,]+)") do
    local trimmed = entry:gsub("^%s+", ""):gsub("%s+$", "")
    if trimmed ~= "" then
      table.insert(servers, trimmed)
    end
  end
  return nk.json_encode({ servers = servers })
end
nk.register_rpc(server_list, "server_list")

-- ------------------------------------------------------------ safety ---
-- Reports are stored by the server (owner = system user, not readable by
-- players). Moderators are the usernames in the ADMIN_USERS env variable.
local SYSTEM_ID = "00000000-0000-0000-0000-000000000000"

local function is_admin(context)
  if context.user_id == nil then return false end
  local raw = (context.env and context.env["ADMIN_USERS"]) or ""
  if raw == "" then return false end
  local users = nk.users_get_id({ context.user_id })
  if #users == 0 then return false end
  local me = users[1].username
  for entry in string.gmatch(raw, "([^,]+)") do
    if entry:gsub("^%s+", ""):gsub("%s+$", "") == me then return true end
  end
  return false
end

local function report(context, payload)
  local data = nk.json_decode(payload ~= "" and payload or "{}")
  local key = ("r%d_%s"):format(math.floor(nk.time() / 1000), string.sub(context.user_id or "anon", 1, 8))
  local ctx = {}
  if type(data.context) == "table" then
    for i = math.max(1, #data.context - 19), #data.context do
      table.insert(ctx, tostring(data.context[i]):sub(1, 200))
    end
  end
  nk.storage_write({{
    collection = "reports", key = key, user_id = SYSTEM_ID,
    value = {
      target = tostring(data.target or ""):sub(1, 80),
      reason = tostring(data.reason or ""):sub(1, 200),
      reporter = tostring(data.reporter or ""):sub(1, 40),
      reporter_id = context.user_id,
      experience = tostring(data.experience or ""):sub(1, 40),
      context = ctx,
      time = math.floor(nk.time() / 1000),
    },
    permission_read = 0, permission_write = 0,
  }})
  return nk.json_encode({ ok = true })
end
nk.register_rpc(report, "report")

local function mod_check(context, payload)
  return nk.json_encode({ admin = is_admin(context) })
end
nk.register_rpc(mod_check, "mod_check")

local function mod_reports(context, payload)
  if not is_admin(context) then error("not allowed") end
  local objects = nk.storage_list(SYSTEM_ID, "reports", 100, "")
  local out = {}
  for _, o in ipairs(objects or {}) do
    local v = o.value
    v.key = o.key
    table.insert(out, v)
  end
  return nk.json_encode({ reports = out })
end
nk.register_rpc(mod_reports, "mod_reports")

local function mod_dismiss(context, payload)
  if not is_admin(context) then error("not allowed") end
  local data = nk.json_decode(payload ~= "" and payload or "{}")
  nk.storage_delete({{ collection = "reports", key = tostring(data.key or ""), user_id = SYSTEM_ID }})
  return nk.json_encode({ ok = true })
end
nk.register_rpc(mod_dismiss, "mod_dismiss")

-- Removes a published community game (index entry + level).
local function mod_remove_game(context, payload)
  if not is_admin(context) then error("not allowed") end
  local data = nk.json_decode(payload ~= "" and payload or "{}")
  local owner = tostring(data.owner or "")
  local key = tostring(data.key or "")
  nk.storage_delete({
    { collection = "games_index", key = key, user_id = owner },
    { collection = "games", key = key, user_id = owner },
  })
  nk.logger_info(("moderator %s removed game %s/%s"):format(context.user_id, owner, key))
  return nk.json_encode({ ok = true })
end
nk.register_rpc(mod_remove_game, "mod_remove_game")

-- -------------------------------------------------------------- admin ---
-- Moderator tools. State per player lives in "mod_state" (owner = system):
--   { banned, ban_ends (0 = forever), chat_ends, kick_at, reason }
-- Every action is written to "mod_log".

local function now_s()
  return math.floor(nk.time() / 1000)
end

local function require_admin(context)
  if not is_admin(context) then error("not allowed") end
end

local function decode(payload)
  return nk.json_decode((payload ~= nil and payload ~= "") and payload or "{}")
end

local function mod_state(uid)
  local objs = nk.storage_read({{ collection = "mod_state", key = uid, user_id = SYSTEM_ID }})
  if objs and #objs > 0 then return objs[1].value end
  return {}
end

local function set_mod_state(uid, v)
  nk.storage_write({{ collection = "mod_state", key = uid, user_id = SYSTEM_ID, value = v,
    permission_read = 0, permission_write = 0 }})
end

local function uid_of(u)
  return u.user_id or u.id
end

local function find_user(query)
  local q = tostring(query or "")
  if q == "" then return nil end
  local users = nk.users_get_username({ q })
  if users and #users > 0 then return users[1] end
  local ok, byid = pcall(nk.users_get_id, { q })
  if ok and byid and #byid > 0 then return byid[1] end
  return nil
end

local function log_action(context, action, target_id, target_name, details)
  local by = ""
  local me = nk.users_get_id({ context.user_id })
  if me and #me > 0 then by = me[1].username end
  local key = string.format("%015d_%s", math.floor(nk.time()), action)
  nk.storage_write({{ collection = "mod_log", key = key, user_id = SYSTEM_ID, permission_read = 0, permission_write = 0,
    value = { by = by, action = action, target_id = target_id, target = target_name,
      details = tostring(details or ""):sub(1, 200), time = now_s() } }})
end

local function admin_user(context, payload)
  require_admin(context)
  local data = decode(payload)
  local u = find_user(data.query)
  if u == nil then return nk.json_encode({ found = false }) end
  local uid = uid_of(u)
  local games = {}
  for _, o in ipairs(nk.storage_list(uid, "games_index", 100, "") or {}) do
    table.insert(games, { key = o.key, name = o.value.name })
  end
  local reports = {}
  for _, o in ipairs(nk.storage_list(SYSTEM_ID, "reports", 100, "") or {}) do
    local t = tostring(o.value.target or "")
    if t == u.username or t == u.display_name then
      local r = o.value
      r.key = o.key
      table.insert(reports, r)
    end
  end
  return nk.json_encode({ found = true, state = mod_state(uid), games = games, reports = reports,
    user = { id = uid, username = u.username, display_name = u.display_name, create_time = u.create_time } })
end
nk.register_rpc(admin_user, "admin_user")

-- Ban: hours > 0 = temporary (lifted automatically on the next login after
-- it ends), 0 = forever. Nakama's own ban also ends open sessions.
local function admin_ban(context, payload)
  require_admin(context)
  local data = decode(payload)
  local uid = tostring(data.user_id or "")
  local hours = tonumber(data.hours) or 0
  local ends = 0
  if hours > 0 then ends = now_s() + math.floor(hours * 3600) end
  nk.users_ban_id({ uid })
  local acc = nk.account_get_id(uid)
  for _, d in ipairs((acc and acc.devices) or {}) do
    nk.storage_write({{ collection = "bans_dev", key = tostring(d.id), user_id = SYSTEM_ID,
      value = { user_id = uid, ends = ends }, permission_read = 0, permission_write = 0 }})
  end
  local st = mod_state(uid)
  st.banned = true
  st.ban_ends = ends
  st.reason = tostring(data.reason or ""):sub(1, 200)
  set_mod_state(uid, st)
  log_action(context, "ban", uid, tostring(data.name or ""), hours > 0 and (hours .. "h: " .. st.reason) or ("forever: " .. st.reason))
  return nk.json_encode({ ok = true, state = st })
end
nk.register_rpc(admin_ban, "admin_ban")

local function lift_ban(uid)
  nk.users_unban_id({ uid })
  local acc = nk.account_get_id(uid)
  for _, d in ipairs((acc and acc.devices) or {}) do
    nk.storage_delete({{ collection = "bans_dev", key = tostring(d.id), user_id = SYSTEM_ID }})
  end
  local st = mod_state(uid)
  st.banned = false
  st.ban_ends = nil
  set_mod_state(uid, st)
  return st
end

local function admin_unban(context, payload)
  require_admin(context)
  local data = decode(payload)
  local st = lift_ban(tostring(data.user_id or ""))
  log_action(context, "unban", data.user_id, tostring(data.name or ""), "")
  return nk.json_encode({ ok = true, state = st })
end
nk.register_rpc(admin_unban, "admin_unban")

-- Temporary bans end on the next login attempt after their time is up.
local function before_auth_device(context, payload)
  local dev = (payload and payload.account and payload.account.id) or ""
  if dev == "" then return payload end
  local objs = nk.storage_read({{ collection = "bans_dev", key = dev, user_id = SYSTEM_ID }})
  if objs and #objs > 0 then
    local v = objs[1].value
    local ends = tonumber(v.ends) or 0
    if ends > 0 and now_s() >= ends then
      lift_ban(tostring(v.user_id))
    end
  end
  return payload
end
nk.register_req_before(before_auth_device, "AuthenticateDevice")

-- Chat mute: hours > 0 mutes until then, 0 removes the mute.
local function admin_mute(context, payload)
  require_admin(context)
  local data = decode(payload)
  local uid = tostring(data.user_id or "")
  local hours = tonumber(data.hours) or 0
  local st = mod_state(uid)
  st.chat_ends = hours > 0 and (now_s() + math.floor(hours * 3600)) or 0
  set_mod_state(uid, st)
  log_action(context, hours > 0 and "mute" or "unmute", uid, tostring(data.name or ""), hours > 0 and (hours .. "h") or "")
  return nk.json_encode({ ok = true, state = st })
end
nk.register_rpc(admin_mute, "admin_mute")

-- Kick: game servers that poll kick_list drop the player within seconds.
local function admin_kick(context, payload)
  require_admin(context)
  local data = decode(payload)
  local uid = tostring(data.user_id or "")
  local st = mod_state(uid)
  st.kick_at = now_s()
  set_mod_state(uid, st)
  log_action(context, "kick", uid, tostring(data.name or ""), "")
  return nk.json_encode({ ok = true })
end
nk.register_rpc(admin_kick, "admin_kick")

local function admin_delete_games(context, payload)
  require_admin(context)
  local data = decode(payload)
  local uid = tostring(data.user_id or "")
  local n = 0
  for _, o in ipairs(nk.storage_list(uid, "games_index", 100, "") or {}) do
    nk.storage_delete({
      { collection = "games_index", key = o.key, user_id = uid },
      { collection = "games", key = o.key, user_id = uid },
    })
    n = n + 1
  end
  log_action(context, "delete_games", uid, tostring(data.name or ""), n .. " games")
  return nk.json_encode({ ok = true, deleted = n })
end
nk.register_rpc(admin_delete_games, "admin_delete_games")

local function admin_log(context, payload)
  require_admin(context)
  local rows = {}
  for _, o in ipairs(nk.storage_list(SYSTEM_ID, "mod_log", 100, "") or {}) do
    local v = o.value
    v.key = o.key
    table.insert(rows, v)
  end
  table.sort(rows, function(a, b) return a.key > b.key end)
  local out = {}
  for i = 1, math.min(50, #rows) do table.insert(out, rows[i]) end
  return nk.json_encode({ log = out })
end
nk.register_rpc(admin_log, "admin_log")

-- For game servers (called with the server http key, no user): who to kick
-- right now and who is muted.
local function kick_list(context, payload)
  if context.user_id ~= nil and context.user_id ~= "" and not is_admin(context) then error("not allowed") end
  local t = now_s()
  local kick = {}
  local mute = {}
  for _, o in ipairs(nk.storage_list(SYSTEM_ID, "mod_state", 100, "") or {}) do
    local v = o.value
    local ka = tonumber(v.kick_at) or 0
    if v.banned or (ka > 0 and t - ka < 120) then table.insert(kick, o.key) end
    local ce = tonumber(v.chat_ends) or 0
    if ce > t then mute[o.key] = ce end
  end
  return nk.json_encode({ kick = kick, mute = mute, now = t })
end
nk.register_rpc(kick_list, "kick_list")

-- A signed pass for joining game servers: "user_id|username|expires|chat_ends|signature".
-- Game servers check it with the same JOIN_SECRET, so banned players
-- (who can't sign in) can't join.
local function join_ticket(context, payload)
  local secret = (context.env and context.env["JOIN_SECRET"]) or ""
  if secret == "" or context.user_id == nil then return nk.json_encode({ ticket = "" }) end
  local st = mod_state(context.user_id)
  local exp = now_s() + 600
  local msg = table.concat({ context.user_id, context.username or "", tostring(exp), tostring(tonumber(st.chat_ends) or 0) }, "|")
  local sig = nk.base16_encode(nk.hmac_sha256_hash(msg, secret))
  return nk.json_encode({ ticket = msg .. "|" .. sig })
end
nk.register_rpc(join_ticket, "join_ticket")

-- Your own moderation status (chat mute) for the app.
local function my_status(context, payload)
  local st = mod_state(context.user_id or "")
  return nk.json_encode({ chat_ends = tonumber(st.chat_ends) or 0, now = now_s() })
end
nk.register_rpc(my_status, "my_status")

-- --------------------------------------------------------- game stats ---
-- Likes / dislikes / plays per game id (library "g:..." ids, featured ids,
-- community "owner/key"). Counters are owned by the server; each player's
-- own vote is remembered so voting again just changes it.

local function stats_key(id)
  return tostring(id or ""):sub(1, 100)
end

local function read_stats(key)
  local objs = nk.storage_read({{ collection = "game_stats", key = key, user_id = SYSTEM_ID }})
  if objs and #objs > 0 then
    local v = objs[1].value
    return { likes = tonumber(v.likes) or 0, dislikes = tonumber(v.dislikes) or 0, plays = tonumber(v.plays) or 0 }
  end
  return { likes = 0, dislikes = 0, plays = 0 }
end

local function write_stats(key, v)
  nk.storage_write({{ collection = "game_stats", key = key, user_id = SYSTEM_ID, value = v,
    permission_read = 2, permission_write = 0 }})
end

local function game_vote(context, payload)
  local data = nk.json_decode(payload ~= "" and payload or "{}")
  local key = stats_key(data.id)
  if key == "" or context.user_id == nil then error("bad request") end
  local v = math.max(-1, math.min(1, math.floor(tonumber(data.v) or 0)))
  local prev = 0
  local mine = nk.storage_read({{ collection = "votes", key = key, user_id = context.user_id }})
  if mine and #mine > 0 then prev = tonumber(mine[1].value.v) or 0 end
  local st = read_stats(key)
  if prev == 1 then st.likes = math.max(0, st.likes - 1) end
  if prev == -1 then st.dislikes = math.max(0, st.dislikes - 1) end
  if v == 1 then st.likes = st.likes + 1 end
  if v == -1 then st.dislikes = st.dislikes + 1 end
  write_stats(key, st)
  nk.storage_write({{ collection = "votes", key = key, user_id = context.user_id, value = { v = v },
    permission_read = 1, permission_write = 0 }})
  st.my = v
  return nk.json_encode(st)
end
nk.register_rpc(game_vote, "game_vote")

local function game_play(context, payload)
  local data = nk.json_decode(payload ~= "" and payload or "{}")
  local key = stats_key(data.id)
  if key == "" then error("bad request") end
  local st = read_stats(key)
  st.plays = st.plays + 1
  write_stats(key, st)
  return nk.json_encode(st)
end
nk.register_rpc(game_play, "game_play")

local function game_stats(context, payload)
  local data = nk.json_decode(payload ~= "" and payload or "{}")
  local ids = {}
  local mine = {}
  for i, id in ipairs(data.ids or {}) do
    if i > 50 then break end
    local key = stats_key(id)
    table.insert(ids, { collection = "game_stats", key = key, user_id = SYSTEM_ID })
    if context.user_id then
      table.insert(mine, { collection = "votes", key = key, user_id = context.user_id })
    end
  end
  local out = {}
  for _, o in ipairs(nk.storage_read(ids) or {}) do
    out[o.key] = { likes = tonumber(o.value.likes) or 0, dislikes = tonumber(o.value.dislikes) or 0,
      plays = tonumber(o.value.plays) or 0, my = 0 }
  end
  if #mine > 0 then
    for _, o in ipairs(nk.storage_read(mine) or {}) do
      if out[o.key] == nil then out[o.key] = { likes = 0, dislikes = 0, plays = 0, my = 0 } end
      out[o.key].my = tonumber(o.value.v) or 0
    end
  end
  return nk.json_encode({ stats = out })
end
nk.register_rpc(game_stats, "game_stats")

nk.logger_info("Roobox module loaded")

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

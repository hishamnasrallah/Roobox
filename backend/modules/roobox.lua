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

nk.logger_info("Roobox module loaded")

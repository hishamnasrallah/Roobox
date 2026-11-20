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

nk.logger_info("Roobox module loaded")

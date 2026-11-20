-- Roobox server logic for Nakama (Lua runtime).
local nk = require("nakama")

-- Course leaderboards: lowest time wins, scores are milliseconds.
local COURSES = {
  obby_land = { min_ms = 20000 },
  sky_tower = { min_ms = 15000 },
}

for id, _ in pairs(COURSES) do
  local ok, err = pcall(nk.leaderboard_create, id, false, "asc", "best", nil, { course = id })
  if not ok then
    nk.logger_info(("leaderboard %s: %s"):format(id, tostring(err)))
  end
end

-- Basic anti-cheat: reject impossible course times and unknown boards.
local function before_write_record(context, payload)
  local board = COURSES[payload.leaderboard_id]
  if board == nil then
    return nil
  end
  local score = tonumber(payload.record.score) or 0
  if score < board.min_ms or score > 3600000 then
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

-- This Source Code Form is subject to the terms
-- of the Mozilla Public License, v. 2.0. If a
-- copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Plugin for switching between windows in constant time
-- Original from: https://gitlab.com/yorickpeterse/nvim-window

local api = vim.api
local fn = vim.fn
local nvim_window = {}

local ESCAPE_KEYCODE = 27

local config = {
	-- Characters used to pick windows, in order of appearance.
	chars = "abcdefg",

	-- Background and text highlight groups.
	background_hl = "Normal",
	text_hl = "Bold",

	-- The border style to use for the floating window.
	border_style = "single",

	-- Floating window width/height.
	float_width = 11,
	float_height = 5,

	-- Whether or not to show letters in uppercase.
	show_uppercase = false,

	-- Directly switch to other window if there are only 2 windows
	skip_if_two = true,
}

---Decomposes a string into a table of characters
local function bytes(str)
	local out = {}
	for i = 1, #str do
		out[i] = string.sub(str, i, i)
	end
	return out
end

---Maps each window to their logical key combinaison.
local function windowKeys(windows)
	local mappings = {}
	local chars = bytes(config.chars)
	local totalChars = #chars
	local current = api.nvim_win_get_number(api.nvim_get_current_win())

	for _, win in ipairs(windows) do
		-- use the window number in order to get consistent letter positionments
		local winNum = api.nvim_win_get_number(win) - 1 -- make it zero-based

		-- since it's zero based
		if (winNum + 1) ~= current then
			-- assume the window numbers are continuous
			local additionalIterations = math.floor(winNum / totalChars)
			local charIndex = (winNum % totalChars) + 1
			local keys = chars[charIndex]
			if additionalIterations > 0 then
				for index = 1, additionalIterations do
					keys = keys .. chars[(winNum - totalChars * index) % totalChars + 1]
				end
			end
			mappings[keys] = win
		end
	end

	return mappings
end

---Opens all the floating windows in the rough middle of every window.
local function openFloatingWindows(mappings)
	local floatingWindows = {}
	local floatWidth, floatHeight = config.float_width, config.float_height
	local upper = config.show_uppercase

	for keys, window in pairs(mappings) do
		local bufNum = api.nvim_create_buf(false, true)

		if bufNum > 0 then
			local width = api.nvim_win_get_width(window)
			local height = api.nvim_win_get_height(window)
			local floatWidth = floatWidth + #keys - 1

			local row = math.max(0, math.floor((height / 2) - 1))
			local col = math.max(0, math.floor((width / 2) - floatWidth))

			local midWidth = math.ceil(floatWidth / 2)
			local midHeight = math.ceil(floatHeight / 2)
			local rep = {}
			for i = 1, midHeight - 1 do
				rep[i] = ""
			end
			rep[midHeight] = string.rep(" ", midWidth - 1) .. (upper and keys:upper() or keys)

			api.nvim_buf_set_lines(bufNum, 0, -1, true, rep)
			api.nvim_buf_add_highlight(bufNum, 0, config.text_hl, 1, 0, -1)

			local window = api.nvim_open_win(bufNum, false, {
				relative = "win",
				win = window,
				row = row,
				col = col,
				width = #keys + floatWidth - 1,
				height = floatHeight,
				focusable = false,
				style = "minimal",
				border = config.border_style,
				noautocmd = true,
			})

			api.nvim_win_set_option(window, "winhl", "Normal:" .. config.background_hl)
			api.nvim_win_set_option(window, "diff", false)

			floatingWindows[window] = bufNum
		end
	end

	-- floating windows will not draw if we don't issue a call to redraw
	vim.cmd("redraw")
	return floatingWindows
end

---Closes all given floating windows.
local function closeFloatingWindows(floatingWindows)
	for window, bufNum in pairs(floatingWindows) do
		api.nvim_win_close(window, true)
		api.nvim_buf_delete(bufNum, { force = true })
	end
end

---Waits for user input
local function getInput()
  local ok, char = pcall(fn.getchar)
  return ok and fn.nr2char(char) or nil
end

---Configures the plugin by merging the given settings into the default ones.
function nvim_window.setup(user_config)
	config = vim.tbl_extend('force', config, user_config)
end

---Picks a window to jump to, and makes it the active window.
function nvim_window.pick()
	local windows = vim.tbl_filter(function(id)
		return api.nvim_win_get_config(id).relative == ""
	end, api.nvim_tabpage_list_wins(0))

	local mappings = windowKeys(windows)
	local key = next(mappings)
	if key == nil then
		return
	end

	if next(mappings, key) == nil then
		api.nvim_set_current_win(mappings[key])
		return
	end

	local windows = openFloatingWindows(mappings)
	local targetWindow = nil

	local iter = 1
	local realIter = 0
	repeat
		realIter = realIter + 1
		local inputKey = getInput()
		if inputKey == nil or inputKey == ESCAPE_KEYCODE then
			closeFloatingWindows(windows)
			return
		end

		local toDelete = {}

		local noneSelected = true
		for targetKey, window in pairs(mappings) do
			local rest = string.sub(targetKey, iter, #targetKey)
			if vim.startswith(inputKey, rest) then
				noneSelected = false
				if #rest == 1 then
					targetWindow = window
					-- is that even portable???
					goto done 
				end
			else
				table.insert(toDelete, targetKey)
			end
		end

		if not noneSelected then
			iter = iter + 1
			for _, key in ipairs(toDelete) do
				mappings[key] = nil
			end
		end
	until realIter > 16

	::done::
	closeFloatingWindows(windows)
	assert(targetWindow, "nvim-window(internal): there should be a target window?")
	api.nvim_set_current_win(targetWindow)
end

return nvim_window


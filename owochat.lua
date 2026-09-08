-- Frontlines UwU Chat
-- Live TextBox version, fixed suffix/cursor handling.
--
-- r/l -> w
-- random stutters at the START of some words
-- ~ at sentence endings
-- exactly ONE :3 / OwO / owo / TwT
--
-- Example:
-- hello bro. where are you
-- h-hewwo bwo.~ whewe awe you~ OwO

local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local env = (getgenv and getgenv()) or _G
local KEY = "__FrontlinesUwUTextboxV6"

--------------------------------------------------
-- CLEAN OLD VERSIONS
--------------------------------------------------

for _, oldKey in ipairs({
	"__FrontlinesUwUTextboxV1",
	"__FrontlinesUwUTextboxV2",
	"__FrontlinesUwUTextboxV3",
	"__FrontlinesUwUTextboxV4",
	"__FrontlinesUwUTextboxV5",
	"__FrontlinesUwUTextboxV6"
}) do
	local old = env[oldKey]

	if old then
		old.Enabled = false

		if old.Connections then
			for _, connection in pairs(old.Connections) do
				pcall(function()
					connection:Disconnect()
				end)
			end
		end
	end
end

pcall(function()
	ContextActionService:UnbindAction("FrontlinesUwUEnter")
end)

--------------------------------------------------
-- CONFIG
--------------------------------------------------

local Config = {
	Enabled = true,

	Faces = {
		":3",
		"OwO",
		"owo",
		"TwT"
	},

	-- 30% of words stutter.
	StutterChance = 0.30,

	-- Rare h-h-hewwo instead of h-hewwo.
	DoubleStutterChance = 0.08
}

--------------------------------------------------
-- STATE
--------------------------------------------------

local state = {
	Enabled = true,
	Connections = {},
	Writing = false,
	Session = nil,
	Box = nil
}

env[KEY] = state
env.FrontlinesUwUChat = state

local rng = Random.new()

--------------------------------------------------
-- R/L -> W
--------------------------------------------------

local replacements = {
	r = "w",
	l = "w",
	R = "W",
	L = "W"
}

local function uwuLetters(text)
	return text:gsub("[rlRL]", replacements)
end

--------------------------------------------------
-- HELPERS
--------------------------------------------------

local function escapePattern(text)
	return text:gsub("([^%w])", "%%%1")
end

local function trimUTF8(text, limit)
	if #text <= limit then
		return text
	end

	text = text:sub(1, limit)

	if utf8 and utf8.len then
		while #text > 0 and not utf8.len(text) do
			text = text:sub(1, -2)
		end
	end

	return text
end

--------------------------------------------------
-- REMOVE FACE WE GENERATED
--------------------------------------------------

local function removeFaces(text)
	for _, face in ipairs(Config.Faces) do
		local pattern = escapePattern(face)

		text = text:gsub(
			"^%s*" .. pattern .. "%s+",
			""
		)

		text = text:gsub(
			"%s+" .. pattern .. "%s*$",
			""
		)
	end

	return text
end

--------------------------------------------------
-- REMOVE GENERATED TILDES
--------------------------------------------------

local function removeTildes(text)
	-- hello.~ -> hello.
	text = text:gsub(
		"([%.%!%?])~+",
		"%1"
	)

	-- Current unfinished sentence:
	-- hello~ -> hello
	text = text:gsub(
		"~+%s*$",
		""
	)

	return text
end

--------------------------------------------------
-- REMOVE GENERATED STUTTERS
--------------------------------------------------

local function removeStutters(text)
	for _ = 1, 5 do
		local changed = false

		text = text:gsub(
			"(%a)%-(%a)",
			function(a, b)
				if a:lower() == b:lower() then
					changed = true
					return b
				end

				return a .. "-" .. b
			end
		)

		if not changed then
			break
		end
	end

	return text
end

--------------------------------------------------
-- SESSION
--------------------------------------------------

local function newSession(box)
	local session = {
		Box = box,

		Face = Config.Faces[
			rng:NextInteger(
				1,
				#Config.Faces
			)
		],

		FaceSide =
			rng:NextInteger(1, 2) == 1
			and "Beginning"
			or "End",

		Stutters = {}
	}

	state.Session = session

	return session
end

--------------------------------------------------
-- STUTTERS
--------------------------------------------------

local function addStutters(text, session)
	local wordIndex = 0

	return text:gsub(
		"(%a)(%a*)",
		function(first, rest)
			wordIndex += 1

			if #rest == 0 then
				return first
			end

			local decision =
				session.Stutters[wordIndex]

			if decision == nil then
				if rng:NextNumber() <= Config.StutterChance then
					if rng:NextNumber() <= Config.DoubleStutterChance then
						decision = 2
					else
						decision = 1
					end
				else
					decision = 0
				end

				session.Stutters[wordIndex] =
					decision
			end

			if decision == 2 then
				return first
					.. "-"
					.. first
					.. "-"
					.. first
					.. rest

			elseif decision == 1 then
				return first
					.. "-"
					.. first
					.. rest
			end

			return first .. rest
		end
	)
end

--------------------------------------------------
-- SENTENCE TILDES
--------------------------------------------------

local function addSentenceTildes(text)
	-- Add ~ immediately after actual sentence punctuation.
	--
	-- hi. what?
	-- hi.~ what?~

	text = text:gsub(
		"([%.%!%?]+)(%s*)",
		function(punctuation, spaces)
			return punctuation
				.. "~"
				.. spaces
		end
	)

	--------------------------------------------------
	-- CURRENT / FINAL SENTENCE
	--------------------------------------------------

	-- If the text already ends in punctuation + ~,
	-- that sentence already has its ending.
	local trimmed =
		text:gsub("%s+$", "")

	if trimmed == "" then
		return text
	end

	if trimmed:sub(-1) == "~" then
		return text
	end

	-- Otherwise the current unfinished/final sentence
	-- gets ONE tilde at the absolute end.
	--
	-- Crucially, the cursor will be positioned BEFORE
	-- this tilde, so new letters get typed before it.

	return text .. "~"
end

--------------------------------------------------
-- FORMAT
--------------------------------------------------

local function format(box)
	if
		not state.Enabled
		or state.Writing
		or not box
		or not box:IsA("TextBox")
	then
		return
	end

	local original =
		box.Text or ""

	if original:match("^%s*$") then
		state.Session = nil
		return
	end

	local session =
		state.Session

	if
		not session
		or session.Box ~= box
	then
		session = newSession(box)
	end

	--------------------------------------------------
	-- GET CLEAN USER TEXT
	--------------------------------------------------

	local text =
		removeFaces(original)

	text =
		removeTildes(text)

	text =
		removeStutters(text)

	text =
		text
			:gsub("%z", "")
			:gsub("[\r\n]", " ")

	--------------------------------------------------
	-- EFFECTS
	--------------------------------------------------

	text =
		uwuLetters(text)

	text =
		addStutters(
			text,
			session
		)

	text =
		addSentenceTildes(text)

	--------------------------------------------------
	-- 100 BYTE LIMIT + FACE
	--------------------------------------------------

	local face =
		session.Face

	local prefix = ""
	local suffix = ""

	if session.FaceSide == "Beginning" then
		prefix =
			face .. " "
	else
		suffix =
			" " .. face
	end

	local available =
		100
		- #prefix
		- #suffix

	text =
		trimUTF8(
			text,
			math.max(1, available)
		)

	-- If trimming cut our final tilde, restore it.
	if
		text ~= ""
		and text:sub(-1) ~= "~"
	then
		text =
			trimUTF8(
				text,
				math.max(0, available - 1)
			)
			.. "~"
	end

	local result =
		prefix
		.. text
		.. suffix

	--------------------------------------------------
	-- UPDATE TEXT
	--------------------------------------------------

	if result == original then
		return
	end

	state.Writing = true

	box.Text = result

	--------------------------------------------------
	-- MOST IMPORTANT FIX
	--
	-- Keep the typing cursor BEFORE:
	--
	--   ~
	--
	-- or:
	--
	--   ~ OwO
	--
	-- This means typing:
	--
	-- h~
	--
	-- then "e" becomes:
	--
	-- he~
	--
	-- NOT:
	--
	-- h~e~
	--------------------------------------------------

	local editableEnd

	if session.FaceSide == "End" then
		-- result:
		-- hello~ OwO
		--
		-- Put cursor before final ~.
		editableEnd =
			#result
			- #suffix
	else
		-- result:
		-- OwO hello~
		editableEnd =
			#result
	end

	-- CursorPosition is 1-based.
	pcall(function()
		box.CursorPosition =
			math.max(
				1,
				editableEnd
			)
	end)

	state.Writing = false
end

--------------------------------------------------
-- ATTACH
--------------------------------------------------

local activeTextConnection
local activeFocusConnection

local function attach(box)
	if
		not box
		or not box:IsA("TextBox")
	then
		return
	end

	if activeTextConnection then
		activeTextConnection:Disconnect()
		activeTextConnection = nil
	end

	if activeFocusConnection then
		activeFocusConnection:Disconnect()
		activeFocusConnection = nil
	end

	state.Box = box
	state.Session = nil

	--------------------------------------------------
	-- LIVE FORMAT
	--------------------------------------------------

	activeTextConnection =
		box:GetPropertyChangedSignal("Text"):Connect(
			function()
				if
					state.Enabled
					and not state.Writing
				then
					format(box)
				end
			end
		)

	--------------------------------------------------
	-- FOCUS LOST
	--------------------------------------------------

	activeFocusConnection =
		box.FocusLost:Connect(
			function()
				task.defer(function()
					if state.Box == box then
						state.Box = nil
					end

					state.Session = nil
				end)
			end
		)

	table.insert(
		state.Connections,
		activeTextConnection
	)

	table.insert(
		state.Connections,
		activeFocusConnection
	)

	format(box)
end

--------------------------------------------------
-- DETECT CHAT TEXTBOX
--------------------------------------------------

table.insert(
	state.Connections,

	UserInputService.TextBoxFocused:Connect(
		function(box)
			if state.Enabled then
				attach(box)
			end
		end
	)
)

--------------------------------------------------
-- STOP
--------------------------------------------------

function state:Stop()
	if not self.Enabled then
		return
	end

	self.Enabled = false

	for _, connection in pairs(
		self.Connections
	) do
		pcall(function()
			connection:Disconnect()
		end)
	end

	table.clear(
		self.Connections
	)

	print(
		"[FrontlinesUwU] Disabled"
	)
end

--------------------------------------------------
-- ALREADY FOCUSED
--------------------------------------------------

local current =
	UserInputService:GetFocusedTextBox()

if current then
	attach(current)
end

print(
	"[FrontlinesUwU] READY | live conversion enabled"
)

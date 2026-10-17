require "import"
import "android.widget.*"
import "android.view.*"
import "android.app.*"
import "android.content.*"
import "android.net.Uri"
import "android.graphics.Color"
import "android.media.AudioAttributes"
import "android.os.Handler"
import "android.os.Looper"
import "android.speech.tts.TextToSpeech"
import "java.util.Locale"
import "org.json.JSONObject"

local URLEncoder = luajava.bindClass("java.net.URLEncoder")
local ctx = activity

local VERSION = "1.2"
local UPDATE_BASE = "https://raw.githubusercontent.com/nabeelhafiz229-afk/accessible-Wikipedia-/main/"
local LOCAL_PATH = "/sdcard/解说/Tools/Accessible Wikipedia/main.lua"


local function enc(s)
  return URLEncoder.encode(s, "UTF-8")
end

local function copyText(label, text)
  local cm = ctx.getSystemService(Context.CLIPBOARD_SERVICE)
  cm.setPrimaryClip(ClipData.newPlainText(label, text))
  Toast.makeText(ctx, "Copied", Toast.LENGTH_SHORT).show()
end

local function showError(title, err)
  pcall(function()
    local full = tostring(title) .. "\n\n" .. tostring(err)
    local tv = TextView(ctx)
    tv.setText(full)
    tv.setTextIsSelectable(true)
    tv.setPadding(40, 40, 40, 40)
    local sv = ScrollView(ctx)
    sv.addView(tv)
    AlertDialog.Builder(ctx)
      .setTitle("Error")
      .setView(sv)
      .setPositiveButton("Copy Error", {onClick = function(d, w) copyText("error", full) end})
      .setNegativeButton("Close", nil)
      .show()
  end)
end

local function httpGet(url, cb)
  Http.get(url, nil, "UTF-8", {["User-Agent"] = "AccessibleWikipedia/1.0"}, function(code, content)
    local ok, e = pcall(function()
      if code ~= 200 or not content then
        error("Network error. HTTP code: " .. tostring(code))
      end
      cb(content)
    end)
    if not ok then showError("Request failed", e) end
  end)
end

local function trim(s)
  s = s:gsub("^%s+", "")
  s = s:gsub("%s+$", "")
  return s
end

local function stripHtml(s)
  s = s:gsub("<[^>]+>", "")
  s = s:gsub("&quot;", '"')
  s = s:gsub("&#039;", "'")
  s = s:gsub("&amp;", "&")
  s = s:gsub("&nbsp;", " ")
  s = s:gsub("%s+", " ")
  return trim(s)
end

local languages = {
  {"English", "en"},
  {"Simple English", "simple"},
  {"Urdu", "ur"},
  {"Arabic", "ar"},
  {"Hindi", "hi"},
  {"Punjabi (Gurmukhi)", "pa"},
  {"Punjabi (Shahmukhi)", "pnb"},
  {"Persian", "fa"},
  {"Pashto", "ps"},
  {"Sindhi", "sd"},
  {"Bengali", "bn"},
  {"Tamil", "ta"},
  {"Turkish", "tr"},
  {"French", "fr"},
  {"German", "de"},
  {"Spanish", "es"},
  {"Portuguese", "pt"},
  {"Italian", "it"},
  {"Russian", "ru"},
  {"Chinese", "zh"},
  {"Japanese", "ja"},
  {"Korean", "ko"},
  {"Indonesian", "id"},
  {"Malay", "ms"},
  {"Dutch", "nl"},
  {"Swahili", "sw"},
  {"Greek", "el"},
  {"Hebrew", "he"},
  {"Thai", "th"},
  {"Vietnamese", "vi"}
}

local modes = {
  {"Normal (select text)", "normal", "Normal"},
  {"Line by line", "line", "Line"},
  {"Word by word", "word", "Word"},
  {"Paragraph by paragraph", "paragraph", "Paragraph"},
  {"Sentence by sentence", "sentence", "Sentence"},
  {"Character by character", "char", "Character"}
}

local sizeOptions = {
  {"Small", 15},
  {"Normal", 18},
  {"Large", 24},
  {"Extra large", 30}
}

local themeOptions = {
  {"Light", "#FFFFFFFF", "#FF000000", "#FF666666"},
  {"Dark", "#FF121212", "#FFFFFFFF", "#FFAAAAAA"},
  {"High contrast (black and yellow)", "#FF000000", "#FFFFFF00", "#FFCCCC00"}
}

local rateOptions = {
  {"Slow", 0.6},
  {"Normal", 1.0},
  {"Fast", 1.5},
  {"Very fast", 2.0}
}

local pitchOptions = {
  {"Low", 0.7},
  {"Normal", 1.0},
  {"High", 1.3}
}

local countOptions = {10, 20, 30, 50}

local aboutText = [[
Accessible Wikipedia

Developed by Prince Nabeel

What this tool is for
Accessible Wikipedia is a simple, screen reader friendly way to search and read Wikipedia. Everything is plain text and large buttons, so you can find any topic and read the whole article easily, without web pages, pop-ups, ads or "Read more" buttons.

What it can do
- Search any topic on Wikipedia. Choose a language from the list, or choose Other and type any Wikipedia language code.
- If your search matches an article title exactly, the article opens directly. Otherwise you get a list of results to choose from.
- The full article is loaded as one piece of text, so you can read it from start to end without interruption.
- References: each paragraph that has references is followed by a References item. Double tap it to read exactly which references support that paragraph, with their sources. In the step-by-step reading modes the tool tells you when a part has references, and the References of this part button opens them. At the end of every article you get the list of references (where the information was taken from) and the article's Wikipedia address. You can jump to them from Sections. Web addresses inside references can be switched on in Settings.
- Sections: jump straight to any part of an article, or go back to the full article.
- Reading modes: Normal (select text), Line by line, Word by word, Paragraph by paragraph, Sentence by sentence and Character by character. When you change the mode you stay at the same place in the article.
- In the step-by-step modes you can use Previous, Next, Repeat, First and Last, jump to an item by its number, and find a word and move to the next or previous match. You can also copy just the current part.
- Read aloud: the article is read with your phone's voice in the article's language. Press the button again to stop.
- Copy or share the whole article or section.
- Settings: text size, theme (light, dark, high contrast), speech speed, pitch and volume channel, number of search results, search result previews, direct opening of exact matches, position announcements, automatic read aloud, showing references and web addresses, keeping the screen on, and resetting everything to default.
- If something goes wrong, the error is shown in a box with text you can select and copy.
- Updates: Settings has a Check for updates button, and the tool can also check by itself when it opens. When a new version is available you can install it with one tap, then reopen the extension.
- Support and Feedback for Developer: a button at the bottom of this screen opens a WhatsApp chat with the developer, so you can report a problem or share an idea.

Notes
An internet connection is needed. Articles come from Wikipedia (wikipedia.org) and are available under the Creative Commons Attribution-ShareAlike license. Read aloud needs a voice for the article's language to be installed on your phone.
]]

local CHARPAT = "[\0-\127\194-\244][\128-\191]*"

local charNames = {[" "] = "space", ["\n"] = "new line", ["\t"] = "tab"}

local terminators = {
  ["."] = true, ["!"] = true, ["?"] = true, ["؟"] = true, ["۔"] = true,
  ["।"] = true, ["。"] = true, ["！"] = true, ["？"] = true
}
local closers = {
  ['"'] = true, ["'"] = true, [")"] = true, ["]"] = true,
  ["»"] = true, ["”"] = true, ["’"] = true
}

local function buildFromText(text)
  local blocks, sections = {}, {}
  local cur = {title = "Introduction", level = 1, from = 1, to = 0}
  sections[1] = cur
  for line in (text .. "\n"):gmatch("(.-)\r?\n") do
    local eq, h = line:match("^(=+)%s*(.-)%s*=+%s*$")
    if eq and #eq >= 2 and h ~= "" then
      h = h:gsub("\1[^\2]*\2", "")
      cur.to = #blocks
      blocks[#blocks + 1] = {text = h, heading = true}
      cur = {title = h, level = #eq, from = #blocks + 1, to = #blocks}
      sections[#sections + 1] = cur
    else
      local ln = trim(line)
      if ln:match("%S") then
        local b = {heading = false, marks = {}}
        local clean, len, i = {}, 0, 1
        while true do
          local ms, me, id, label = ln:find("\1([^\2|]*)|([^\2]*)\2", i)
          if not ms then
            clean[#clean + 1] = ln:sub(i)
            break
          end
          local chunk = ln:sub(i, ms - 1)
          clean[#clean + 1] = chunk
          len = len + #chunk
          b.marks[#b.marks + 1] = {pos = len + 1, id = id, label = label}
          i = me + 1
        end
        b.text = table.concat(clean)
        if b.text:match("%S") then
          blocks[#blocks + 1] = b
          cur.to = #blocks
        end
      end
    end
  end
  return {blocks = blocks, sections = sections}
end

local function wordUnits(text)
  local u = {}
  for s, w, e in text:gmatch("()(%S+)()") do
    u[#u + 1] = {s = s, e = e - 1}
  end
  return u
end

local function paragraphUnits(text)
  local u = {}
  for s, seg, e in text:gmatch("()([^\n]+)()") do
    if seg:match("%S") then u[#u + 1] = {s = s, e = e - 1} end
  end
  return u
end

local function charUnits(text)
  local u = {}
  for s, ch in text:gmatch("()(" .. CHARPAT .. ")") do
    u[#u + 1] = {s = s, e = s + #ch - 1}
  end
  return u
end

local function sentenceUnits(text)
  local u = {}
  local start, last, pending = nil, nil, false
  local function flush()
    if start then u[#u + 1] = {s = start, e = last} end
    start, last, pending = nil, nil, false
  end
  for s, ch in text:gmatch("()(" .. CHARPAT .. ")") do
    local e = s + #ch - 1
    if ch == "\n" then
      flush()
    elseif ch == " " or ch == "\t" then
      if pending then flush() end
    else
      if not start then start = s end
      last = e
      if terminators[ch] then
        pending = true
      elseif not closers[ch] then
        pending = false
      end
    end
  end
  flush()
  return u
end

local function lineUnits(text, paint, maxW)
  local u = {}
  local spaceW = paint.measureText(" ")
  for ps, seg, pe in text:gmatch("()([^\n]+)()") do
    local ls, le, curW = nil, nil, 0
    for ws, w, we in seg:gmatch("()(%S+)()") do
      local ww = paint.measureText(w)
      local absS = ps + ws - 1
      local absE = ps + we - 2
      if not ls then
        ls, le, curW = absS, absE, ww
      elseif curW + spaceW + ww > maxW then
        u[#u + 1] = {s = ls, e = le}
        ls, le, curW = absS, absE, ww
      else
        le = absE
        curW = curW + spaceW + ww
      end
    end
    if ls then u[#u + 1] = {s = ls, e = le} end
  end
  return u
end

local function indexFor(units, cursor)
  local lo, hi = 1, #units
  local ans = #units
  if ans < 1 then return 1 end
  while lo <= hi do
    local mid = math.floor((lo + hi) / 2)
    if units[mid].e >= cursor then
      ans = mid
      hi = mid - 1
    else
      lo = mid + 1
    end
  end
  return ans
end

local function decodeEntities(s)
  s = s:gsub("&nbsp;", " ")
  s = s:gsub("&lt;", "<")
  s = s:gsub("&gt;", ">")
  s = s:gsub("&quot;", '"')
  s = s:gsub("&#(%d+);", function(n)
    local c = tonumber(n)
    if not c then return "" end
    if utf8 and utf8.char and c < 1114112 then return utf8.char(c) end
    if c < 128 then return string.char(c) end
    return ""
  end)
  s = s:gsub("&#[xX](%x+);", function(h)
    local c = tonumber(h, 16)
    if not c then return "" end
    if utf8 and utf8.char and c < 1114112 then return utf8.char(c) end
    if c < 128 then return string.char(c) end
    return ""
  end)
  s = s:gsub("&amp;", "&")
  return s
end

local function htmlToText(html, withMarkers)
  html = html:gsub("<style.-</style>", "")
  html = html:gsub("<script.-</script>", "")
  html = html:gsub("<ol[^>]*class=\"[^\"]*references[^\"]*\"[^>]*>.-</ol>", "")
  html = html:gsub("<table.-</table>", "")
  html = html:gsub("<figure.-</figure>", "")
  if withMarkers then
    html = html:gsub("<sup[^>]*class=\"[^\"]*reference[^\"]*\"[^>]*>.-</sup>", function(sup)
      local id = sup:match("href=\"#([^\"]+)\"") or ""
      local plain = sup:gsub("<[^>]+>", "")
      local label = plain:match("%[(.-)%]") or ""
      return "\1" .. id .. "|" .. label .. "\2"
    end)
  end
  html = html:gsub("<sup[^>]*>.-</sup>", "")
  html = html:gsub("<h(%d)[^>]*>(.-)</h%d>", function(lv, inner)
    inner = inner:gsub("<[^>]+>", "")
    local t = trim(decodeEntities(inner))
    if t == "" then return "\n" end
    local eq = string.rep("=", tonumber(lv))
    return "\n\n" .. eq .. " " .. t .. " " .. eq .. "\n"
  end)
  html = html:gsub("<li[^>]*>", "\n- ")
  html = html:gsub("</p>", "\n")
  html = html:gsub("<br[^>]*>", "\n")
  html = html:gsub("</li>", "\n")
  html = html:gsub("</div>", "\n")
  html = html:gsub("<[^>]+>", "")
  html = decodeEntities(html)
  html = html:gsub("[ \t]+\n", "\n")
  html = html:gsub("\n\n\n+", "\n\n")
  return trim(html)
end

local function fetchHtmlSafe(pageTitle, lang, cb)
  local url = "https://" .. lang .. ".wikipedia.org/w/api.php?action=parse&format=json&formatversion=2&redirects=1&disableeditsection=1&prop=text%7Cdisplaytitle&page=" .. enc(pageTitle)
  Http.get(url, nil, "UTF-8", {["User-Agent"] = "AccessibleWikipedia/1.0"}, function(code, content)
    local ok, html, ttl = pcall(function()
      if code ~= 200 or not content then return nil, nil end
      local root = JSONObject(content)
      local p = root.optJSONObject("parse")
      if not p then return nil, nil end
      return p.optString("text"), p.optString("title")
    end)
    if ok then
      cb(html, ttl)
    else
      cb(nil, nil)
    end
  end)
end

local function parseRefs(html)
  local byId, ordered = {}, {}
  for ol in html:gmatch("<ol[^>]*class=\"[^\"]*references[^\"]*\"[^>]*>.-</ol>") do
    for attrs, li in ol:gmatch("<li([^>]*)>(.-)</li>") do
      local id = attrs:match("id=\"([^\"]+)\"")
      local url = li:match("href=\"(https?://[^\"]+)\"")
      local t = li
      t = t:gsub("<span class=\"mw%-cite%-backlink\">.-</span>", "")
      t = t:gsub("<style.-</style>", "")
      t = t:gsub("<[^>]+>", " ")
      t = decodeEntities(t)
      t = t:gsub("↑", "")
      t = t:gsub("%s+", " ")
      t = trim(t)
      t = t:gsub("^%^%s*", "")
      if t ~= "" then
        local rec = {text = t, url = url}
        ordered[#ordered + 1] = rec
        if id then byId[decodeEntities(id)] = rec end
      end
    end
  end
  return byId, ordered
end

local function parseVersion(v)
  local t = {}
  for n in tostring(v):gmatch("%d+") do t[#t + 1] = tonumber(n) end
  return t
end

local function isNewer(remote, current)
  local a, b = parseVersion(remote), parseVersion(current)
  for i = 1, math.max(#a, #b) do
    local x, y = a[i] or 0, b[i] or 0
    if x > y then return true end
    if x < y then return false end
  end
  return false
end

local function fetchText(url, cb)
  Http.get(url .. "?t=" .. os.time(), nil, "UTF-8", {["User-Agent"] = "AccessibleWikipedia/1.0", ["Cache-Control"] = "no-cache"}, function(code, content)
    local ok, e = pcall(function()
      cb(code == 200 and content ~= nil and #content > 0, content, code)
    end)
    if not ok then showError("Update problem", e) end
  end)
end

local function saveUpdate(content)
  local target = luajava.newInstance("java.io.File", LOCAL_PATH)
  local parent = target.getParentFile()
  if parent and not parent.exists() then parent.mkdirs() end
  local tmp = luajava.newInstance("java.io.File", LOCAL_PATH .. ".new")
  local fos = luajava.newInstance("java.io.FileOutputStream", tmp)
  local writer = luajava.newInstance("java.io.OutputStreamWriter", fos, "UTF-8")
  writer.write(content)
  writer.close()
  if tmp.length() < 5000 then
    tmp.delete()
    error("The downloaded file is too small, so it was not installed.")
  end
  local bak = luajava.newInstance("java.io.File", LOCAL_PATH .. ".bak")
  if bak.exists() then bak.delete() end
  if target.exists() then target.renameTo(bak) end
  if not tmp.renameTo(target) then
    if bak.exists() then bak.renameTo(target) end
    error("Could not replace the old main.lua file at " .. LOCAL_PATH)
  end
end

local function downloadUpdate(remote)
  Toast.makeText(ctx, "Downloading the update...", Toast.LENGTH_SHORT).show()
  fetchText(UPDATE_BASE .. "main.lua", function(ok, content, code)
    if not ok then
      error("Could not download the update. HTTP code: " .. tostring(code))
    end
    if not content:find("local function buildUI", 1, true) or not content:find("pcall(buildUI)", 1, true) then
      error("The downloaded file does not look like a valid tool file, so it was not installed.")
    end
    saveUpdate(content)
    local newVer = content:match("local VERSION = \"([^\"]+)\"") or remote
    AlertDialog.Builder(ctx)
      .setTitle("Update installed")
      .setMessage("The tool was updated to version " .. newVer .. ". Please close this extension and open it again to start the new version.")
      .setPositiveButton("OK", nil)
      .show()
  end)
end

local function askUpdate(remote)
  AlertDialog.Builder(ctx)
    .setTitle("Update available")
    .setMessage("A new version " .. remote .. " is available. You are using version " .. VERSION .. ". Do you want to update now?")
    .setPositiveButton("Update now", {onClick = function(d, w)
      local ok, e = pcall(function() downloadUpdate(remote) end)
      if not ok then showError("Update failed", e) end
    end})
    .setNegativeButton("Later", nil)
    .show()
end

local function checkUpdates(manual)
  fetchText(UPDATE_BASE .. "version.txt", function(ok, content, code)
    if not ok then
      if manual then error("Could not check for updates. HTTP code: " .. tostring(code)) end
      return
    end
    local remote = trim(content):match("%d[%d%.]*")
    if not remote then
      if manual then error("The version file does not contain a version number.") end
      return
    end
    if isNewer(remote, VERSION) then
      askUpdate(remote)
    elseif manual then
      AlertDialog.Builder(ctx)
        .setTitle("No update needed")
        .setMessage("You already have the latest version (" .. VERSION .. ").")
        .setPositiveButton("OK", nil)
        .show()
    end
  end)
end

local function buildUI()
  local prefs = ctx.getSharedPreferences("accessible_wikipedia", 0)

  local S = {
    size = prefs.getInt("size", 1),
    theme = prefs.getInt("theme", 0),
    mode = prefs.getInt("mode", 0),
    rate = prefs.getInt("rate", 1),
    pitch = prefs.getInt("pitch", 1),
    count = prefs.getInt("count", 1),
    snippets = prefs.getBoolean("snippets", true),
    autoopen = prefs.getBoolean("autoopen", true),
    announcepos = prefs.getBoolean("announcepos", false),
    autoread = prefs.getBoolean("autoread", false),
    keepon = prefs.getBoolean("keepon", false),
    autoupdate = prefs.getBoolean("autoupdate", true),
    voicech = prefs.getInt("voicech", 0),
    refs = prefs.getBoolean("refs", true),
    refurls = prefs.getBoolean("refurls", false),
    refmarks = prefs.getBoolean("refmarks", true),
    refannounce = prefs.getBoolean("refannounce", true)
  }
  if S.size < 0 or S.size >= #sizeOptions then S.size = 1 end
  if S.theme < 0 or S.theme >= #themeOptions then S.theme = 0 end
  if S.mode < 0 or S.mode >= #modes then S.mode = 0 end
  if S.rate < 0 or S.rate >= #rateOptions then S.rate = 1 end
  if S.pitch < 0 or S.pitch >= #pitchOptions then S.pitch = 1 end
  if S.count < 0 or S.count >= #countOptions then S.count = 1 end
  if S.voicech < 0 or S.voicech > 1 then S.voicech = 0 end

  local langIndex = prefs.getInt("lang", 0)
  local customCode = prefs.getString("langcode", "")
  if langIndex < 0 or langIndex > #languages then langIndex = 0 end

  local function saveInt(k, v) prefs.edit().putInt(k, v).apply() end
  local function saveBool(k, v) prefs.edit().putBoolean(k, v).apply() end

  local layout = LinearLayout(ctx)
  layout.setOrientation(1)
  layout.setPadding(30, 30, 30, 30)

  local title = TextView(ctx)
  title.setText("Accessible Wikipedia")
  title.setTextSize(22)
  layout.addView(title)

  local creditView = TextView(ctx)
  creditView.setText("Developed by Prince Nabeel")
  creditView.setTextSize(16)
  layout.addView(creditView)

  local searchBlock = LinearLayout(ctx)
  searchBlock.setOrientation(1)

  local langBtn = Button(ctx)
  searchBlock.addView(langBtn)

  local input = EditText(ctx)
  input.setHint("Search Wikipedia")
  input.setSingleLine(true)
  searchBlock.addView(input)

  local searchBtn = Button(ctx)
  searchBtn.setText("Search")
  searchBlock.addView(searchBtn)

  local settingsBtn = Button(ctx)
  settingsBtn.setText("Settings")
  searchBlock.addView(settingsBtn)

  layout.addView(searchBlock)

  local status = TextView(ctx)
  status.setText("")
  layout.addView(status)

  local articleBar = LinearLayout(ctx)
  articleBar.setOrientation(1)
  articleBar.setVisibility(8)
  local barRow = LinearLayout(ctx)
  barRow.setOrientation(0)
  local backBtn = Button(ctx)
  backBtn.setText("Back to results")
  local sectionsBtn = Button(ctx)
  sectionsBtn.setText("Sections")
  barRow.addView(backBtn, LinearLayout.LayoutParams(0, -2, 1))
  barRow.addView(sectionsBtn, LinearLayout.LayoutParams(0, -2, 1))
  local modeRow = LinearLayout(ctx)
  modeRow.setOrientation(0)
  local modeBtn = Button(ctx)
  local readBtn = Button(ctx)
  readBtn.setText("Read aloud / Stop")
  modeRow.addView(modeBtn, LinearLayout.LayoutParams(0, -2, 3))
  modeRow.addView(readBtn, LinearLayout.LayoutParams(0, -2, 2))
  articleBar.addView(barRow)
  articleBar.addView(modeRow)
  layout.addView(articleBar)

  local resultsScroll = ScrollView(ctx)
  resultsScroll.setVisibility(8)
  local resultsBox = LinearLayout(ctx)
  resultsBox.setOrientation(1)
  resultsScroll.addView(resultsBox)
  layout.addView(resultsScroll, LinearLayout.LayoutParams(-1, 0, 1))

  local sv = ScrollView(ctx)
  local articleBox = LinearLayout(ctx)
  articleBox.setOrientation(1)
  sv.addView(articleBox)
  local measureView = TextView(ctx)
  layout.addView(sv, LinearLayout.LayoutParams(-1, 0, 1))

  local unitScroll = ScrollView(ctx)
  unitScroll.setVisibility(8)
  local unitPanel = LinearLayout(ctx)
  unitPanel.setOrientation(1)
  local unitView = TextView(ctx)
  unitView.setPadding(10, 20, 10, 20)
  pcall(function() unitView.setTextDirection(2) end)
  local posView = TextView(ctx)
  posView.setText("")
  local navRow = LinearLayout(ctx)
  navRow.setOrientation(0)
  local prevBtn = Button(ctx)
  prevBtn.setText("Previous")
  local nextBtn = Button(ctx)
  nextBtn.setText("Next")
  navRow.addView(prevBtn, LinearLayout.LayoutParams(0, -2, 1))
  navRow.addView(nextBtn, LinearLayout.LayoutParams(0, -2, 1))
  local navRow2 = LinearLayout(ctx)
  navRow2.setOrientation(0)
  local repeatBtn = Button(ctx)
  repeatBtn.setText("Repeat")
  local copyUnitBtn = Button(ctx)
  copyUnitBtn.setText("Copy this part")
  navRow2.addView(repeatBtn, LinearLayout.LayoutParams(0, -2, 1))
  navRow2.addView(copyUnitBtn, LinearLayout.LayoutParams(0, -2, 1))
  local navRow3 = LinearLayout(ctx)
  navRow3.setOrientation(0)
  local firstBtn = Button(ctx)
  firstBtn.setText("First")
  local lastBtn = Button(ctx)
  lastBtn.setText("Last")
  navRow3.addView(firstBtn, LinearLayout.LayoutParams(0, -2, 1))
  navRow3.addView(lastBtn, LinearLayout.LayoutParams(0, -2, 1))
  local refsBtn = Button(ctx)
  refsBtn.setText("References of this part")
  local goInput = EditText(ctx)
  goInput.setHint("Go to number")
  goInput.setSingleLine(true)
  goInput.setInputType(2)
  local goBtn = Button(ctx)
  goBtn.setText("Go")
  local findInput = EditText(ctx)
  findInput.setHint("Find in article")
  findInput.setSingleLine(true)
  local findRow = LinearLayout(ctx)
  findRow.setOrientation(0)
  local findNextBtn = Button(ctx)
  findNextBtn.setText("Find next")
  local findPrevBtn = Button(ctx)
  findPrevBtn.setText("Find previous")
  findRow.addView(findNextBtn, LinearLayout.LayoutParams(0, -2, 1))
  findRow.addView(findPrevBtn, LinearLayout.LayoutParams(0, -2, 1))
  unitPanel.addView(unitView)
  unitPanel.addView(posView)
  unitPanel.addView(navRow)
  unitPanel.addView(navRow2)
  unitPanel.addView(navRow3)
  unitPanel.addView(refsBtn)
  unitPanel.addView(goInput)
  unitPanel.addView(goBtn)
  unitPanel.addView(findInput)
  unitPanel.addView(findRow)
  unitScroll.addView(unitPanel)
  layout.addView(unitScroll, LinearLayout.LayoutParams(-1, 0, 1))

  local bottomBar = LinearLayout(ctx)
  bottomBar.setOrientation(0)
  bottomBar.setVisibility(8)
  local copyBtn = Button(ctx)
  copyBtn.setText("Copy")
  local shareBtn = Button(ctx)
  shareBtn.setText("Share")
  local newSearchBtn = Button(ctx)
  newSearchBtn.setText("New search")
  bottomBar.addView(copyBtn, LinearLayout.LayoutParams(0, -2, 1))
  bottomBar.addView(shareBtn, LinearLayout.LayoutParams(0, -2, 1))
  bottomBar.addView(newSearchBtn, LinearLayout.LayoutParams(0, -2, 1))
  layout.addView(bottomBar)

  local results = {}
  local article = nil
  local marksGlobal = {}
  local shownText = ""
  local currentBlocks = {{text = "Choose a language, type what you want to search, and press Search.", heading = false}}
  local articleLang = "en"
  local mode = modes[S.mode + 1][2]
  local unitCache = {}
  local idx = 1
  local cursor = 1
  local tts = nil
  local ttsReady = false
  local reading = false
  local startedOK = false
  local idleCount = 0
  local handler = nil
  local pollReading

  pcall(function()
    tts = TextToSpeech(ctx, TextToSpeech.OnInitListener{
      onInit = function(st)
        ttsReady = (st == TextToSpeech.SUCCESS)
      end
    })
  end)

  pcall(function()
    handler = Handler(Looper.getMainLooper())
  end)

  pollReading = function()
    if not reading or not handler then return end
    handler.postDelayed(Runnable{
      run = function()
        pcall(function()
          if not reading then return end
          if tts and tts.isSpeaking() then
            idleCount = 0
          else
            idleCount = idleCount + 1
          end
          if idleCount >= 3 then
            reading = false
          else
            pollReading()
          end
        end)
      end
    }, 800)
  end

  local function modeName(m)
    for _, x in ipairs(modes) do
      if x[2] == m then return x[1] end
    end
    return m
  end

  local function modeLabel(m)
    for _, x in ipairs(modes) do
      if x[2] == m then return x[3] end
    end
    return "Item"
  end

  local function langName()
    if langIndex >= #languages then
      if customCode ~= "" then return "Other (" .. customCode .. ")" end
      return "Other (not set)"
    end
    return languages[langIndex + 1][1]
  end

  local function updateLangButton()
    langBtn.setText("Language: " .. langName())
  end

  local function updateModeButton()
    modeBtn.setText("Reading mode: " .. modeName(mode))
  end

  local function getLang()
    if langIndex >= #languages then
      if customCode ~= "" then return customCode end
      return nil
    end
    return languages[langIndex + 1][2]
  end

  local function renderResults()
    resultsBox.removeAllViews()
    local th = themeOptions[S.theme + 1]
    local sz = sizeOptions[S.size + 1][2]
    for i, r in ipairs(results) do
      local tv = TextView(ctx)
      local label = r.title
      if S.snippets and r.snip ~= "" then label = r.title .. ": " .. r.snip end
      tv.setText(label)
      tv.setTextSize(sz)
      tv.setTextColor(Color.parseColor(th[3]))
      tv.setPadding(20, 28, 20, 28)
      tv.setClickable(true)
      tv.setFocusable(true)
      tv.setOnClickListener(View.OnClickListener{
        onClick = function(v)
          local ok, e = pcall(function() r.open() end)
          if not ok then showError("Load failed", e) end
        end
      })
      resultsBox.addView(tv)
    end
  end

  local function lookupRef(m)
    if not article then return nil end
    local r = article.refById[m.id]
    if not r then
      local n = tonumber(m.label)
      if n then r = article.refOrdered[n] end
    end
    return r
  end

  local function showRefDialog(marks)
    local seen, lines = {}, {}
    for _, m in ipairs(marks) do
      local key = m.id .. "|" .. m.label
      if not seen[key] then
        seen[key] = true
        local r = lookupRef(m)
        local line
        if r then
          line = "Reference " .. m.label .. ": " .. r.text
          if r.url then line = line .. "\n" .. r.url end
        else
          line = "Reference " .. m.label .. ": the details of this reference were not found."
        end
        lines[#lines + 1] = line
      end
    end
    if #lines == 0 then
      Toast.makeText(ctx, "No references here", Toast.LENGTH_SHORT).show()
      return
    end
    local text = table.concat(lines, "\n\n")
    local tv = TextView(ctx)
    tv.setText(text)
    tv.setTextIsSelectable(true)
    tv.setTextSize(18)
    tv.setPadding(40, 30, 40, 30)
    local scroll = ScrollView(ctx)
    scroll.addView(tv)
    AlertDialog.Builder(ctx)
      .setTitle("References")
      .setView(scroll)
      .setPositiveButton("Close", nil)
      .setNegativeButton("Copy", {onClick = function(d, w) copyText("references", text) end})
      .show()
  end

  local function marksIn(s, e)
    local list = {}
    for _, m in ipairs(marksGlobal) do
      if m.pos > s and m.pos <= e + 1 then list[#list + 1] = m end
    end
    return list
  end

  local function labelsOf(marks)
    local labels, seen = {}, {}
    for _, m in ipairs(marks) do
      if not seen[m.label] then
        seen[m.label] = true
        labels[#labels + 1] = m.label
      end
    end
    return table.concat(labels, ", ")
  end

  local function renderBlocks()
    articleBox.removeAllViews()
    local th = themeOptions[S.theme + 1]
    local fg = Color.parseColor(th[3])
    local sz = sizeOptions[S.size + 1][2]
    for _, b in ipairs(currentBlocks) do
      local tv = TextView(ctx)
      tv.setText(b.text)
      tv.setTextColor(fg)
      tv.setTextIsSelectable(true)
      pcall(function() tv.setTextDirection(2) end)
      if b.heading then
        tv.setTextSize(sz + 4)
        tv.setPadding(10, 30, 10, 10)
        pcall(function() tv.setTypeface(nil, 1) end)
        pcall(function() tv.setAccessibilityHeading(true) end)
      else
        tv.setTextSize(sz)
        tv.setPadding(10, 14, 10, 14)
      end
      articleBox.addView(tv)
      if (not b.heading) and S.refmarks and b.marks and #b.marks > 0 then
        local marks = b.marks
        local rv = TextView(ctx)
        rv.setText("References: " .. labelsOf(marks) .. ". Double tap to read them.")
        rv.setTextSize(sz - 2)
        rv.setTextColor(fg)
        rv.setPadding(40, 4, 10, 20)
        rv.setClickable(true)
        rv.setFocusable(true)
        rv.setOnClickListener(View.OnClickListener{
          onClick = function(v)
            local ok, e = pcall(function() showRefDialog(marks) end)
            if not ok then showError("References failed", e) end
          end
        })
        articleBox.addView(rv)
      end
    end
  end

  local function applyTheme()
    local th = themeOptions[S.theme + 1]
    local bg = Color.parseColor(th[2])
    local fg = Color.parseColor(th[3])
    local hint = Color.parseColor(th[4])
    layout.setBackgroundColor(bg)
    for _, tv in ipairs({title, creditView, status, unitView, posView}) do
      tv.setTextColor(fg)
    end
    for _, et in ipairs({input, goInput, findInput}) do
      et.setTextColor(fg)
      et.setHintTextColor(hint)
    end
    renderResults()
    renderBlocks()
  end

  local function getUnits()
    if unitCache[mode] then return unitCache[mode] end
    local u
    if mode == "line" then
      local ok, res = pcall(function()
        local w = ctx.getResources().getDisplayMetrics().widthPixels - 100
        return lineUnits(shownText, measureView.getPaint(), w)
      end)
      if ok then u = res else u = paragraphUnits(shownText) end
    elseif mode == "word" then
      u = wordUnits(shownText)
    elseif mode == "paragraph" then
      u = paragraphUnits(shownText)
    elseif mode == "sentence" then
      u = sentenceUnits(shownText)
    else
      u = charUnits(shownText)
    end
    unitCache[mode] = u
    return u
  end

  local function present(announce)
    local units = getUnits()
    if #units == 0 then
      unitView.setText("No text")
      posView.setText("")
      return
    end
    if idx < 1 then idx = 1 end
    if idx > #units then idx = #units end
    local u = units[idx]
    cursor = u.s
    local t = shownText:sub(u.s, u.e)
    local label = t
    if mode == "char" then label = charNames[t] or t end
    local position = modeLabel(mode) .. " " .. idx .. " of " .. #units
    unitView.setText(label)
    posView.setText(position)
    if announce then
      local spoken = label
      if S.refannounce and mode ~= "char" then
        local ms = marksIn(u.s, u.e)
        if #ms > 0 then spoken = spoken .. ". Reference " .. labelsOf(ms) end
      end
      if S.announcepos then spoken = spoken .. ". " .. position end
      pcall(function() unitView.announceForAccessibility(spoken) end)
    end
  end

  local function say(msg)
    pcall(function() unitView.announceForAccessibility(msg) end)
    Toast.makeText(ctx, msg, Toast.LENGTH_SHORT).show()
  end

  local function applyTextSize()
    local sz = sizeOptions[S.size + 1][2]
    measureView.setTextSize(sz)
    unitView.setTextSize(sz + 4)
    unitCache = {}
    renderResults()
    renderBlocks()
    if article and mode == "line" then
      idx = indexFor(getUnits(), cursor)
      present(false)
    end
  end

  local function layoutArticle()
    searchBlock.setVisibility(8)
    resultsScroll.setVisibility(8)
    articleBar.setVisibility(0)
    bottomBar.setVisibility(0)
    if #results == 0 then
      backBtn.setVisibility(8)
    else
      backBtn.setVisibility(0)
    end
    if mode == "normal" then
      sv.setVisibility(0)
      unitScroll.setVisibility(8)
    else
      sv.setVisibility(8)
      unitScroll.setVisibility(0)
    end
  end

  local function showResultsView()
    searchBlock.setVisibility(0)
    sv.setVisibility(8)
    unitScroll.setVisibility(8)
    articleBar.setVisibility(8)
    bottomBar.setVisibility(8)
    resultsScroll.setVisibility(0)
  end

  local function setArticleBlocks(blocks)
    local texts = {}
    local pos = 1
    marksGlobal = {}
    for _, b in ipairs(blocks) do
      b.start = pos
      texts[#texts + 1] = b.text
      if b.marks then
        for _, m in ipairs(b.marks) do
          marksGlobal[#marksGlobal + 1] = {pos = pos + m.pos - 1, id = m.id, label = m.label}
        end
      end
      pos = pos + #b.text + 1
    end
    shownText = table.concat(texts, "\n")
    currentBlocks = blocks
    unitCache = {}
    idx = 1
    cursor = 1
    renderBlocks()
    sv.scrollTo(0, 0)
    if mode ~= "normal" then present(true) end
  end

  local function showFullArticle()
    local blocks = {{text = article.title, heading = true}}
    for _, b in ipairs(article.blocks) do blocks[#blocks + 1] = b end
    setArticleBlocks(blocks)
  end

  local function showSection(i)
    local sec = article.sections[i]
    local blocks = {{text = article.title .. " - " .. sec.title, heading = true}}
    for k = sec.from, sec.to do blocks[#blocks + 1] = article.blocks[k] end
    if #blocks == 1 then
      blocks[2] = {text = "This section has no text of its own. Open its subsections from the Sections list.", heading = false, marks = {}}
    end
    setArticleBlocks(blocks)
  end

  local function applyMode(newMode)
    mode = newMode
    updateModeButton()
    if not article then return end
    if mode ~= "normal" then
      local units = getUnits()
      idx = indexFor(units, cursor)
      present(true)
    end
    layoutArticle()
  end

  local function startReading()
    if not tts or not ttsReady then
      Toast.makeText(ctx, "Voice engine is not ready", Toast.LENGTH_SHORT).show()
      return
    end
    if shownText == "" then return end
    local from = 1
    if mode ~= "normal" then from = cursor end
    local text = shownText:sub(from)
    local code = articleLang
    if code == "simple" then code = "en" end
    if code == "pnb" then code = "ur" end
    local r = tts.setLanguage(Locale(code))
    if r < 0 then
      Toast.makeText(ctx, "A voice for this language may not be installed", Toast.LENGTH_LONG).show()
    end
    pcall(function()
      tts.setSpeechRate(rateOptions[S.rate + 1][2])
      tts.setPitch(pitchOptions[S.pitch + 1][2])
    end)
    pcall(function()
      local usage = 11
      if S.voicech == 1 then usage = 1 end
      local attrs = AudioAttributes.Builder().setUsage(usage).setContentType(1).build()
      tts.setAudioAttributes(attrs)
    end)
    local chunks = {}
    local cur = ""
    for _, u in ipairs(sentenceUnits(text)) do
      local s = text:sub(u.s, u.e)
      if #cur + #s > 600 and cur ~= "" then
        chunks[#chunks + 1] = cur
        cur = ""
      end
      if #s > 600 then
        for w in s:gmatch("%S+") do
          if #cur + #w > 600 then
            chunks[#chunks + 1] = cur
            cur = ""
          end
          cur = cur .. w .. " "
        end
      else
        cur = cur .. s .. " "
      end
    end
    if cur ~= "" then chunks[#chunks + 1] = cur end
    if #chunks == 0 then return end
    local failed = nil
    for i, c in ipairs(chunks) do
      local queueMode = 1
      if i == 1 then queueMode = 0 end
      local res = tts.speak(c, queueMode, nil, "wiki" .. i)
      if res ~= 0 and not failed then failed = res end
    end
    if failed then
      error("The voice engine refused to speak (code " .. tostring(failed) .. "). Engine: " .. tostring(tts.getDefaultEngine()) .. ". Language result: " .. tostring(r))
    end
    reading = true
    startedOK = true
    idleCount = 0
    pollReading()
  end

  local function stopReading()
    pcall(function() tts.stop() end)
    reading = false
  end

  local function toggleReading()
    if reading then
      stopReading()
      return
    end
    reading = true
    if not handler then
      startedOK = false
      startReading()
      if not startedOK then reading = false end
      return
    end
    handler.postDelayed(Runnable{
      run = function()
        if not reading then return end
        startedOK = false
        local ok, e = pcall(startReading)
        if not startedOK then reading = false end
        if not ok then showError("Read aloud failed", e) end
      end
    }, 700)
  end

  local function loadArticle(pageTitle, lang)
    status.setText("Loading article...")
    local function finishOpen(parsed, ttl, byId, ordered)
      local blocks, sections = parsed.blocks, parsed.sections
      if #blocks == 0 then
        blocks[1] = {text = "No text is available for this article.", heading = false, marks = {}}
        sections[1].to = 1
      end
      if S.refs then
        if #ordered > 0 then
          blocks[#blocks + 1] = {text = "Reference list", heading = true}
          local sec = {title = "Reference list", level = 2, from = #blocks + 1, to = #blocks}
          for i, r in ipairs(ordered) do
            local t = i .. ". " .. r.text
            if S.refurls and r.url then t = t .. " (" .. r.url .. ")" end
            blocks[#blocks + 1] = {text = t, heading = false, marks = {}}
          end
          sec.to = #blocks
          sections[#sections + 1] = sec
        end
        blocks[#blocks + 1] = {text = "Article source", heading = true}
        local sec2 = {title = "Article source", level = 2, from = #blocks + 1, to = #blocks + 1}
        blocks[#blocks + 1] = {
          text = "This article is from Wikipedia: https://" .. lang .. ".wikipedia.org/wiki/" .. (ttl:gsub(" ", "_")),
          heading = false, marks = {}
        }
        sections[#sections + 1] = sec2
      end
      article = {title = ttl, blocks = blocks, sections = sections, refById = byId or {}, refOrdered = ordered or {}}
      articleLang = lang
      status.setText("")
      showFullArticle()
      layoutArticle()
      if S.autoread then
        pcall(function()
          if reading then stopReading() end
          startReading()
        end)
      end
    end

    local function useExtracts()
      local baseUrl = "https://" .. lang .. ".wikipedia.org/w/api.php?action=query&prop=extracts&explaintext=1&redirects=1&format=json&formatversion=2&titles=" .. enc(pageTitle)
      local parts = {}
      local realTitle = pageTitle
      local function fetch(cont, depth)
        local url = baseUrl
        if cont then url = url .. "&excontinue=" .. enc(cont) end
        httpGet(url, function(content)
          local root = JSONObject(content)
          local page = root.getJSONObject("query").getJSONArray("pages").getJSONObject(0)
          if page.has("missing") then
            status.setText("Article not found")
            return
          end
          realTitle = page.getString("title")
          parts[#parts + 1] = page.optString("extract")
          local c = root.optJSONObject("continue")
          if c and c.has("excontinue") and depth < 10 then
            status.setText("Loading the rest of the article...")
            fetch(c.optString("excontinue"), depth + 1)
            return
          end
          finishOpen(buildFromText(table.concat(parts, "")), realTitle, {}, {})
        end)
      end
      fetch(nil, 0)
    end

    fetchHtmlSafe(pageTitle, lang, function(html, ttlHtml)
      local ok, err = pcall(function()
        if html then
          local parsed = buildFromText(htmlToText(html, true))
          if #parsed.blocks > 0 then
            local byId, ordered = parseRefs(html)
            local ttl = ttlHtml
            if not ttl or ttl == "" then ttl = pageTitle end
            finishOpen(parsed, ttl, byId, ordered)
            return
          end
        end
        useExtracts()
      end)
      if not ok then showError("Opening the article failed", err) end
    end)
  end

  local function search(query, lang)
    status.setText("Searching...")
    local url = "https://" .. lang .. ".wikipedia.org/w/api.php?action=query&list=search&srlimit=" .. countOptions[S.count + 1] .. "&srinfo=suggestion&format=json&utf8=1&srsearch=" .. enc(query)
    httpGet(url, function(content)
      local root = JSONObject(content)
      local q = root.getJSONObject("query")
      local arr = q.getJSONArray("search")
      results = {}
      for i = 0, arr.length() - 1 do
        local o = arr.getJSONObject(i)
        local t = o.getString("title")
        local snip = stripHtml(o.optString("snippet"))
        if #snip > 120 then snip = snip:sub(1, 120) end
        results[#results + 1] = {
          title = t,
          snip = snip,
          open = function() loadArticle(t, lang) end
        }
      end
      renderResults()
      if #results == 0 then
        local sug = ""
        local info = q.optJSONObject("searchinfo")
        if info then sug = info.optString("suggestion") end
        if sug ~= "" then
          status.setText("No results. Did you mean: " .. sug .. "?")
        else
          status.setText("No results found")
        end
        return
      end
      if S.autoopen and results[1].title:lower() == query:lower() then
        loadArticle(results[1].title, lang)
        return
      end
      status.setText(#results .. " results. Tap one to read it.")
      showResultsView()
    end)
  end

  local function move(delta)
    local units = getUnits()
    local n = idx + delta
    if n > #units then
      say("End of text")
      return
    end
    if n < 1 then
      say("Start of text")
      return
    end
    idx = n
    present(true)
  end

  local function findText(q, forward)
    local units = getUnits()
    if #units == 0 then return end
    local hay = shownText:lower()
    local needle = q:lower()
    local ms = {}
    local p = 1
    while #ms < 5000 do
      local f = hay:find(needle, p, true)
      if not f then break end
      ms[#ms + 1] = f
      p = f + 1
    end
    if #ms == 0 then
      say("Not found")
      return
    end
    local u = units[idx]
    local target = nil
    local wrapped = false
    if forward then
      for _, m in ipairs(ms) do
        if m > u.e then
          target = m
          break
        end
      end
      if not target then
        target = ms[1]
        wrapped = true
      end
    else
      for i = #ms, 1, -1 do
        if ms[i] < u.s then
          target = ms[i]
          break
        end
      end
      if not target then
        target = ms[#ms]
        wrapped = true
      end
    end
    idx = indexFor(units, target)
    present(true)
    if wrapped then
      Toast.makeText(ctx, "Search wrapped around", Toast.LENGTH_SHORT).show()
    end
  end

  local function askLanguageCode()
    local et = EditText(ctx)
    et.setHint("Language code, for example sv or uk")
    et.setSingleLine(true)
    et.setText(customCode)
    AlertDialog.Builder(ctx)
      .setTitle("Other language")
      .setMessage("Enter the Wikipedia language code. It is the part before .wikipedia.org in a Wikipedia address.")
      .setView(et)
      .setPositiveButton("OK", {onClick = function(d, w)
        local ok, e = pcall(function()
          local c = trim(tostring(et.getText())):lower()
          if c == "" or not c:match("^[%a%-]+$") then
            Toast.makeText(ctx, "That is not a valid language code", Toast.LENGTH_LONG).show()
            return
          end
          customCode = c
          langIndex = #languages
          saveInt("lang", langIndex)
          prefs.edit().putString("langcode", customCode).apply()
          updateLangButton()
        end)
        if not ok then showError("Language failed", e) end
      end})
      .setNegativeButton("Cancel", nil)
      .show()
  end

  local function chooseLanguage()
    local lv = ListView(ctx)
    local adapter = ArrayAdapter(ctx, android.R.layout.simple_list_item_1)
    for _, l in ipairs(languages) do adapter.add(l[1]) end
    adapter.add("Other (enter language code)")
    lv.setAdapter(adapter)
    local dlg = AlertDialog.Builder(ctx)
      .setTitle("Choose language")
      .setView(lv)
      .setNegativeButton("Cancel", nil)
      .show()
    lv.setOnItemClickListener(AdapterView.OnItemClickListener{
      onItemClick = function(p, v, pos, id)
        dlg.dismiss()
        local ok, e = pcall(function()
          if pos >= #languages then
            askLanguageCode()
          else
            langIndex = pos
            saveInt("lang", langIndex)
            updateLangButton()
          end
        end)
        if not ok then showError("Language failed", e) end
      end
    })
  end

  local function chooseMode()
    local lv = ListView(ctx)
    local adapter = ArrayAdapter(ctx, android.R.layout.simple_list_item_1)
    for _, m in ipairs(modes) do adapter.add(m[1]) end
    lv.setAdapter(adapter)
    local dlg = AlertDialog.Builder(ctx)
      .setTitle("Reading mode")
      .setView(lv)
      .setNegativeButton("Cancel", nil)
      .show()
    lv.setOnItemClickListener(AdapterView.OnItemClickListener{
      onItemClick = function(p, v, pos, id)
        dlg.dismiss()
        local ok, e = pcall(function() applyMode(modes[pos + 1][2]) end)
        if not ok then showError("Reading mode failed", e) end
      end
    })
  end

  local function showAbout()
    local box = LinearLayout(ctx)
    box.setOrientation(1)
    box.setPadding(40, 30, 40, 30)
    local tv = TextView(ctx)
    tv.setText(aboutText .. "\nVersion " .. VERSION)
    tv.setTextIsSelectable(true)
    box.addView(tv)
    local waBtn = Button(ctx)
    waBtn.setText("Support and Feedback for Developer")
    waBtn.setOnClickListener(View.OnClickListener{
      onClick = function(v)
        local ok, e = pcall(function()
          local it = Intent(Intent.ACTION_VIEW, Uri.parse("https://wa.me/923234375740"))
          ctx.startActivity(it)
        end)
        if not ok then showError("Could not open WhatsApp", e) end
      end
    })
    box.addView(waBtn)
    local scroll = ScrollView(ctx)
    scroll.addView(box)
    AlertDialog.Builder(ctx)
      .setTitle("About")
      .setView(scroll)
      .setPositiveButton("Close", nil)
      .show()
  end

  local openSettings

  local function resetSettings()
    S.size, S.theme, S.mode, S.rate, S.pitch, S.count = 1, 0, 0, 1, 1, 1
    S.snippets, S.autoopen, S.announcepos, S.autoread, S.keepon = true, true, false, false, false
    S.voicech = 0
    S.refs, S.refurls = true, false
    S.refmarks, S.refannounce = true, true
    S.autoupdate = true
    local ed = prefs.edit()
    ed.putInt("size", 1)
    ed.putInt("theme", 0)
    ed.putInt("mode", 0)
    ed.putInt("rate", 1)
    ed.putInt("pitch", 1)
    ed.putInt("count", 1)
    ed.putInt("voicech", 0)
    ed.putBoolean("snippets", true)
    ed.putBoolean("autoopen", true)
    ed.putBoolean("announcepos", false)
    ed.putBoolean("autoread", false)
    ed.putBoolean("keepon", false)
    ed.putBoolean("refs", true)
    ed.putBoolean("refurls", false)
    ed.putBoolean("refmarks", true)
    ed.putBoolean("refannounce", true)
    ed.putBoolean("autoupdate", true)
    ed.apply()
    layout.setKeepScreenOn(false)
    applyTheme()
    applyTextSize()
    applyMode("normal")
  end

  openSettings = function()
    local scroll = ScrollView(ctx)
    local box = LinearLayout(ctx)
    box.setOrientation(1)
    box.setPadding(40, 20, 40, 20)
    scroll.addView(box)

    local function label(text)
      local t = TextView(ctx)
      t.setText(text)
      t.setTextSize(16)
      t.setPadding(0, 24, 0, 0)
      box.addView(t)
    end

    local function choice(name, items, current, onPick)
      label(name)
      local sp = Spinner(ctx)
      sp.setContentDescription(name)
      local ad = ArrayAdapter(ctx, android.R.layout.simple_spinner_item)
      ad.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
      for _, it in ipairs(items) do ad.add(it) end
      sp.setAdapter(ad)
      sp.setSelection(current)
      sp.setOnItemSelectedListener(AdapterView.OnItemSelectedListener{
        onItemSelected = function(p, v, pos, id)
          local ok, e = pcall(function() onPick(pos) end)
          if not ok then showError("Setting failed", e) end
        end,
        onNothingSelected = function(p) end
      })
      box.addView(sp)
    end

    local function toggle(name, current, onChange)
      local cb = CheckBox(ctx)
      cb.setText(name)
      cb.setChecked(current)
      cb.setOnCheckedChangeListener(CompoundButton.OnCheckedChangeListener{
        onCheckedChanged = function(btn, checked)
          local ok, e = pcall(function() onChange(checked) end)
          if not ok then showError("Setting failed", e) end
        end
      })
      box.addView(cb)
    end

    local names = {}
    for _, o in ipairs(sizeOptions) do names[#names + 1] = o[1] end
    choice("Text size", names, S.size, function(pos)
      if pos == S.size then return end
      S.size = pos
      saveInt("size", pos)
      applyTextSize()
    end)

    names = {}
    for _, o in ipairs(themeOptions) do names[#names + 1] = o[1] end
    choice("Theme", names, S.theme, function(pos)
      if pos == S.theme then return end
      S.theme = pos
      saveInt("theme", pos)
      applyTheme()
    end)

    names = {}
    for _, o in ipairs(modes) do names[#names + 1] = o[1] end
    choice("Default reading mode", names, S.mode, function(pos)
      if pos == S.mode then return end
      S.mode = pos
      saveInt("mode", pos)
      applyMode(modes[pos + 1][2])
    end)

    names = {}
    for _, o in ipairs(rateOptions) do names[#names + 1] = o[1] end
    choice("Read aloud speed", names, S.rate, function(pos)
      S.rate = pos
      saveInt("rate", pos)
    end)

    names = {}
    for _, o in ipairs(pitchOptions) do names[#names + 1] = o[1] end
    choice("Read aloud pitch", names, S.pitch, function(pos)
      S.pitch = pos
      saveInt("pitch", pos)
    end)

    choice("Read aloud volume channel", {"Accessibility volume (recommended)", "Media volume"}, S.voicech, function(pos)
      S.voicech = pos
      saveInt("voicech", pos)
    end)

    names = {}
    for _, o in ipairs(countOptions) do names[#names + 1] = o .. " search results" end
    choice("Number of search results", names, S.count, function(pos)
      S.count = pos
      saveInt("count", pos)
    end)

    toggle("Show a short preview with each search result", S.snippets, function(c)
      S.snippets = c
      saveBool("snippets", c)
      renderResults()
    end)

    toggle("Open the article directly when the search matches its title", S.autoopen, function(c)
      S.autoopen = c
      saveBool("autoopen", c)
    end)

    toggle("Announce the position with each item in reading modes", S.announcepos, function(c)
      S.announcepos = c
      saveBool("announcepos", c)
    end)

    toggle("Read the article aloud automatically after opening it", S.autoread, function(c)
      S.autoread = c
      saveBool("autoread", c)
    end)

    toggle("Show references and the article source at the end of the article", S.refs, function(c)
      S.refs = c
      saveBool("refs", c)
    end)

    toggle("Show a References item after each paragraph that has references", S.refmarks, function(c)
      S.refmarks = c
      saveBool("refmarks", c)
      renderBlocks()
    end)

    toggle("Announce which parts have references in reading modes", S.refannounce, function(c)
      S.refannounce = c
      saveBool("refannounce", c)
    end)

    toggle("Show web addresses in the references", S.refurls, function(c)
      S.refurls = c
      saveBool("refurls", c)
    end)

    toggle("Keep the screen on", S.keepon, function(c)
      S.keepon = c
      saveBool("keepon", c)
      layout.setKeepScreenOn(c)
    end)

    local dlg = AlertDialog.Builder(ctx)
      .setTitle("Settings")
      .setView(scroll)
      .setPositiveButton("Close", nil)
      .create()

    toggle("Check for updates automatically when the tool opens", S.autoupdate, function(c)
      S.autoupdate = c
      saveBool("autoupdate", c)
    end)

    local updBtn = Button(ctx)
    updBtn.setText("Check for updates")
    updBtn.setOnClickListener(View.OnClickListener{
      onClick = function(v)
        local ok, e = pcall(function() checkUpdates(true) end)
        if not ok then showError("Update check failed", e) end
      end
    })
    box.addView(updBtn)

    local resetBtn = Button(ctx)
    resetBtn.setText("Reset settings to default")
    resetBtn.setOnClickListener(View.OnClickListener{
      onClick = function(v)
        local ok, e = pcall(function()
          resetSettings()
          dlg.dismiss()
          openSettings()
        end)
        if not ok then showError("Reset failed", e) end
      end
    })
    box.addView(resetBtn)

    local aboutBtn = Button(ctx)
    aboutBtn.setText("About")
    aboutBtn.setOnClickListener(View.OnClickListener{
      onClick = function(v)
        local ok, e = pcall(showAbout)
        if not ok then showError("About failed", e) end
      end
    })
    box.addView(aboutBtn)

    dlg.show()
  end

  langBtn.setOnClickListener(View.OnClickListener{
    onClick = function(v)
      local ok, e = pcall(chooseLanguage)
      if not ok then showError("Language failed", e) end
    end
  })

  settingsBtn.setOnClickListener(View.OnClickListener{
    onClick = function(v)
      local ok, e = pcall(openSettings)
      if not ok then showError("Settings failed", e) end
    end
  })

  modeBtn.setOnClickListener(View.OnClickListener{
    onClick = function(v)
      local ok, e = pcall(chooseMode)
      if not ok then showError("Reading mode failed", e) end
    end
  })

  searchBtn.setOnClickListener(View.OnClickListener{
    onClick = function(v)
      local ok, e = pcall(function()
        local query = trim(tostring(input.getText()))
        if query == "" then
          Toast.makeText(ctx, "Type something to search", Toast.LENGTH_SHORT).show()
          return
        end
        local lang = getLang()
        if not lang then
          Toast.makeText(ctx, "Choose a language first", Toast.LENGTH_SHORT).show()
          return
        end
        search(query, lang)
      end)
      if not ok then showError("Search failed", e) end
    end
  })

  backBtn.setOnClickListener(View.OnClickListener{
    onClick = function(v)
      local ok, e = pcall(function()
        showResultsView()
        status.setText(#results .. " results. Tap one to read it.")
      end)
      if not ok then showError("Back failed", e) end
    end
  })

  sectionsBtn.setOnClickListener(View.OnClickListener{
    onClick = function(v)
      local ok, e = pcall(function()
        if not article or #article.sections <= 1 then
          Toast.makeText(ctx, "This article has no sections", Toast.LENGTH_SHORT).show()
          return
        end
        local lv = ListView(ctx)
        local adapter = ArrayAdapter(ctx, android.R.layout.simple_list_item_1)
        adapter.add("Full article")
        for i, s in ipairs(article.sections) do
          if i == 1 then
            adapter.add("Introduction")
          elseif s.level > 2 then
            adapter.add("- " .. s.title)
          else
            adapter.add(s.title)
          end
        end
        lv.setAdapter(adapter)
        local dlg = AlertDialog.Builder(ctx)
          .setTitle("Sections")
          .setView(lv)
          .setNegativeButton("Cancel", nil)
          .show()
        lv.setOnItemClickListener(AdapterView.OnItemClickListener{
          onItemClick = function(p, vv, pos, id)
            dlg.dismiss()
            local ok2, e2 = pcall(function()
              if pos == 0 then
                showFullArticle()
              else
                showSection(pos)
              end
            end)
            if not ok2 then showError("Section failed", e2) end
          end
        })
      end)
      if not ok then showError("Sections failed", e) end
    end
  })

  prevBtn.setOnClickListener(View.OnClickListener{
    onClick = function(v)
      local ok, e = pcall(function() move(-1) end)
      if not ok then showError("Previous failed", e) end
    end
  })

  nextBtn.setOnClickListener(View.OnClickListener{
    onClick = function(v)
      local ok, e = pcall(function() move(1) end)
      if not ok then showError("Next failed", e) end
    end
  })

  repeatBtn.setOnClickListener(View.OnClickListener{
    onClick = function(v)
      local ok, e = pcall(function() present(true) end)
      if not ok then showError("Repeat failed", e) end
    end
  })

  refsBtn.setOnClickListener(View.OnClickListener{
    onClick = function(v)
      local ok, e = pcall(function()
        local units = getUnits()
        local u = units[idx]
        if not u then return end
        local ms = marksIn(u.s, u.e)
        if #ms == 0 then
          say("This part has no references")
          return
        end
        showRefDialog(ms)
      end)
      if not ok then showError("References failed", e) end
    end
  })

  copyUnitBtn.setOnClickListener(View.OnClickListener{
    onClick = function(v)
      local ok, e = pcall(function()
        local units = getUnits()
        local u = units[idx]
        if u then copyText("part", shownText:sub(u.s, u.e)) end
      end)
      if not ok then showError("Copy failed", e) end
    end
  })

  firstBtn.setOnClickListener(View.OnClickListener{
    onClick = function(v)
      local ok, e = pcall(function()
        idx = 1
        present(true)
      end)
      if not ok then showError("First failed", e) end
    end
  })

  lastBtn.setOnClickListener(View.OnClickListener{
    onClick = function(v)
      local ok, e = pcall(function()
        idx = #getUnits()
        present(true)
      end)
      if not ok then showError("Last failed", e) end
    end
  })

  goBtn.setOnClickListener(View.OnClickListener{
    onClick = function(v)
      local ok, e = pcall(function()
        local n = tonumber(trim(tostring(goInput.getText())))
        local units = getUnits()
        if not n or n < 1 or n > #units then
          say("Enter a number from 1 to " .. #units)
          return
        end
        idx = math.floor(n)
        present(true)
      end)
      if not ok then showError("Go to failed", e) end
    end
  })

  findNextBtn.setOnClickListener(View.OnClickListener{
    onClick = function(v)
      local ok, e = pcall(function()
        local q = trim(tostring(findInput.getText()))
        if q == "" then
          say("Type what to find")
          return
        end
        findText(q, true)
      end)
      if not ok then showError("Find failed", e) end
    end
  })

  findPrevBtn.setOnClickListener(View.OnClickListener{
    onClick = function(v)
      local ok, e = pcall(function()
        local q = trim(tostring(findInput.getText()))
        if q == "" then
          say("Type what to find")
          return
        end
        findText(q, false)
      end)
      if not ok then showError("Find failed", e) end
    end
  })

  copyBtn.setOnClickListener(View.OnClickListener{
    onClick = function(v)
      if shownText ~= "" then copyText("article", shownText) end
    end
  })

  shareBtn.setOnClickListener(View.OnClickListener{
    onClick = function(v)
      if shownText == "" then return end
      local ok, e = pcall(function()
        local it = Intent(Intent.ACTION_SEND)
        it.setType("text/plain")
        it.putExtra(Intent.EXTRA_TEXT, shownText)
        ctx.startActivity(Intent.createChooser(it, "Share"))
      end)
      if not ok then showError("Share failed", e) end
    end
  })

  newSearchBtn.setOnClickListener(View.OnClickListener{
    onClick = function(v)
      local ok, e = pcall(function()
        searchBlock.setVisibility(0)
        sv.setVisibility(8)
        unitScroll.setVisibility(8)
        articleBar.setVisibility(8)
        bottomBar.setVisibility(8)
        if #results > 0 then
          resultsScroll.setVisibility(0)
          status.setText(#results .. " results. Tap one to read it.")
        else
          resultsScroll.setVisibility(8)
          status.setText("")
        end
        input.requestFocus()
      end)
      if not ok then showError("New search failed", e) end
    end
  })

  readBtn.setOnClickListener(View.OnClickListener{
    onClick = function(v)
      local ok, e = pcall(toggleReading)
      if not ok then showError("Read aloud failed", e) end
    end
  })

  updateLangButton()
  updateModeButton()
  applyTextSize()
  applyTheme()
  layout.setKeepScreenOn(S.keepon)
  ctx.setContentView(layout)
  if S.autoupdate then
    pcall(function() checkUpdates(false) end)
  end
end

local ok, err = pcall(buildUI)
if not ok then showError("Startup failed", err) end

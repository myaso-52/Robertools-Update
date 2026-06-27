script_name("Robertools") 
script_author("Sanek Prokuratura")   
script_version("4.0") 

local samplua = require 'lib.samp.events'
local ffi = require 'ffi'
local inicfg = require 'inicfg'
local http = require 'ssl.https' 

ffi.cdef[[
    bool MessageBeep(unsigned int uType);
]]

-- Ññûëêè ñòðîãî íà âàø ðåïîçèòîðèé GitHub (myaso-52)
local github_user = "myaso-52"
local github_repo = "Robertools-Update"
local url_version = "https://githubusercontent.com" .. github_user .. "/" .. github_repo .. "/main/version.txt"
local url_script = "https://githubusercontent.com" .. github_user .. "/" .. github_repo .. "/main/Robertools.lua"
local url_staff = "https://githubusercontent.com" .. github_user .. "/" .. github_repo .. "/main/Robertools_Staff.uni.ini"

local config_dir = getWorkingDirectory() .. "/config"
if not doesDirectoryExist(config_dir) then createDirectory(config_dir) end
local ini_path = "Robertools_Staff.uni.ini"

function checkAutoUpdate()
    local response, code = http.request(url_version)
    if code == 200 and response then
        local server_version = response:match("^%s*(.-)%s*$")
        if server_version and server_version ~= thisScript().version then
            sampAddChatMessage("{00FFCC}[Robertools v3]{FFFFFF} Íàéäåíî îáíîâëåíèå! Ñêà÷èâàþ âåðñèþ " .. server_version, -1)
            local new_code, script_code = http.request(url_script)
            if script_code == 200 and new_code then
                local file = io.open(thisScript().path, "wb")
                if file then file:write(new_code) file:close() end
                sampAddChatMessage("{00FF00}[Robertools v3]{FFFFFF} Óñïåøíî îáíîâëåíî! Íàæìèòå Ctrl + R.", -1)
            end
        end
    end
end

function downloadStaffList()
    local response, code = http.request(url_staff)
    if code == 200 and response then
        local file = io.open(config_dir .. "/" .. ini_path, "wb")
        if file then file:write(response) file:close() end
    end
end

pcall(downloadStaffList)
local default_ini = { Staff = { ["Sanek_Prokuratura"] = "3", ["Robert_Robinson"] = "3" }, Blacklist = {} }
local main_ini = inicfg.load(default_ini, ini_path) or default_ini
local config_path = "Robertools_config.ini"
local default_config = {
    Answers = {
        ans1 = "Çäðàâñòâóéòå, ñïåøó íà ïîìîùü! Ïðèÿòíîé èãðû.",
        ans2 = "Çäðàâñòâóéòå, íå çàñîðÿéòå ðåïîðò. Ïðèÿòíîé èãðû!",
        ans3 = "Çäðàâñòâóéòå, íà÷èíàþ ñëåæêó. Ïðèÿòíîé èãðû.",
        ans4 = "Çäðàâñòâóéòå, Îñòàâüòå æàëîáó â ñâîáîäíîé ãðóïïå ÂÊ - @inferno_Sv",
        ans5 = "Çäðàâñòâóéòå, ïîæàëóéñòà, îæèäàéòå. Ïðèÿòíîé èãðû!",
        ans6 = "Çäðàâñòâóéòå, ïðèÿòíîé èãðû îò Roberta )"
    }
}
local answer_cfg = inicfg.load(default_config, config_path) or default_config
local ans1, ans2, ans3 = answer_cfg.Answers.ans1, answer_cfg.Answers.ans2, answer_cfg.Answers.ans3
local ans4, ans5, ans6 = answer_cfg.Answers.ans4, answer_cfg.Answers.ans5, answer_cfg.Answers.ans6

local last_report_id, invis_active, is_panel_banned = "", false, false
local panel_ban_reason, razdash_active, razdash_word = "Íå óêàçàíà", false, ""
local razdash_item_id, razdash_value, razdash_mode = "", "", 1
local tp_stage, mute_stage, target_mute_id = 0, 0, nil
local items_database = {
    ["1"] = "èãðîâîãî óðîâíÿ", ["2"] = "çàêîíîïîñëóøíîñòè", ["3"] = "ìàòåðèàëîâ",
    ["4"] = "óáèéñòâ", ["5"] = "íîìåðà òåëåôîíà", ["6"] = "EXP (îïûòà)",
    ["7"] = "äåíåã â áàíêå", ["8"] = "äåíåã íà ìîáèëå", ["9"] = "íàëè÷íûõ äåíåã",
    ["10"] = "àïòå÷åê", ["15"] = "íàðêîçàâèñèìîñòè", ["16"] = "íàðêîòèêîâ"
}
local objects_database = {
    ["1"] = "øëÿïó êóðèöû", ["2"] = "îãîíåê íà ãîëîâó", ["3"] = "ìèãàëêó íà ãîëîâó",
    ["4"] = "÷åðíóþ ìàñêó", ["10"] = "ìàñêó äðàêîíà", ["11"] = "ëàçåð íà ãîëîâó",
    ["12"] = "êîìïëåêò âñåìîãóùèé", ["13"] = "ïîïóãàÿ íà ïëå÷î", ["14"] = "ÿðêèé ñâåò",
    ["15"] = "áîëüøîé Ì4", ["16"] = "îáúåêò-ïóñòûøêà", ["17"] = "êîñòþì ïîïóãàÿ"
}
local insult_words = { "÷ìî", "ïèäîð", "åáëàí", "äàóí", "àóòèñò", "òóïîðûëûé", "èäèîò", "ïðèäóðîê", "õóéëî", "ãàíäîí", "mðàçü", "øëþõà", "äîëáîåá", "ïèäîðàñ", "óåáîê", "óåáàí", "óåáàíèùå" }
local rodnya_words = { "ìàòü", "ìàìå", "ìàìó", "ìàìà", "ïàïà", "ïàïó", "ïàìå", "îò÷èì", "îòåö", "îòöà", "îòöó", "áàòÿ", "áàòå", "ìà÷åõ", "ðîäèòåë", "âûáëÿä", "mq", "mku", "ñø", "áåçìàìí", "áåç ìàìí" }

function getItemNameById(id, mode)
    return mode == 2 and (objects_database[tostring(id)] or "îáúåêò #" .. tostring(id)) or (items_database[tostring(id)] or "ïðåäìåò #" .. tostring(id))
end
function string.cp1251lower(str)
    local upper = "ÀÁÂÃÄÅ¨ÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖ×ØÙÚÛÜÝÞßABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local lower = "àáâãäå¸æçèéêëìíîïðñòóôõö÷øùúûüýþÿabcdefghijklmnopqrstuvwxyz"
    local res = ""
    for i = 1, #str do
        local c = str:sub(i, i)
        local pos = upper:find(c, 1, true)
        res = res .. (pos and lower:sub(pos, pos) or c)
    end
    return res
end

local function formatNickname(nick)
    local formatted = nick:lower():gsub("^%l", string.upper)
    return formatted:gsub("_(%l)", function(l) return "_" .. l:upper() end)
end

function logMuteAction(player_id, reason_word, type_id)
    local log_path = config_dir .. "/Robertools_Mutes.txt"
    local file = io.open(log_path, "a")
    if file then
        local time_str = os.date("%Y-%m-%d [%H:%M:%S]")
        local type_str = (type_id == 2) and "Îñê. Ðîäíûõ" or "Mat/Îñê"
        local p_name = sampIsPlayerConnected(tonumber(player_id)) and sampGetPlayerNickname(tonumber(player_id)) or "Unknown"
        file:write(string.format("%s Íàðóøèòåëü: %s[%s] | Òèï: %s | Òðèããåð: %s\n", time_str, p_name, player_id, type_str, reason_word))
        file:close()
    end
end
function checkAndMuteAnyChat(full_line_text)
    if is_panel_banned or mute_stage > 0 then return false end 
    local lower_text = string.cp1251lower(full_line_text)
    
    for _, word in ipairs(rodnya_words) do
        if string.find(lower_text, word, 1, true) then
            local player_id = full_line_text:match("%[%s*(%d+)%s*%]")
            if player_id then
                target_mute_id = tonumber(player_id)
                mute_stage = 2 
                pcall(ffi.C.MessageBeep, 0)
                sampAddChatMessage(string.format("{FF3333}[Warning]{FFFFFF} Çàïðåùåííîå ñëîâî \"%s\", ìóò ÷åðåç 2ñ", word), -1)
                logMuteAction(player_id, word, 2)
                lua_thread.create(function() wait(2000) sampSendChat(string.format("/mute %s", player_id)) end)
                return true
            end
        end
    end
    for _, word in ipairs(insult_words) do
        if string.find(lower_text, word, 1, true) then
            local player_id = full_line_text:match("%[%s*(%d+)%s*%]")
            if player_id then
                target_mute_id = tonumber(player_id)
                mute_stage = 1 
                pcall(ffi.C.MessageBeep, 0)
                sampAddChatMessage(string.format("{FF3333}[Warning]{FFFFFF} Çàïðåùåííîå ñëîâî \"%s\", ìóò ÷åðåç 2ñ", word), -1)
                logMuteAction(player_id, word, 1)
                lua_thread.create(function() wait(2000) sampSendChat(string.format("/mute %s", player_id)) end)
                return true
            end
        end
    end
    return false
end

function getPlayerStaffLevel()
    local result, my_id = sampGetPlayerIdByCharHandle(PLAYER_PED)
    if not result or not my_id then return 1, "{22FF22}Þçåð" end
    local my_nickname = sampGetPlayerNickname(my_id)
    local low_nick = my_nickname:lower()
    
    if low_nick == "robert_robinson" then return 3, "{FF3333}Ðàçðàáîò÷èê {FFFFFF}| ÂÊ: {00FFCC}@dimo4kaenergy" end
    if low_nick == "sanek_prokuratura" then return 3, "{FF3333}Ðàçðàáîò÷èê" end
    
    if main_ini and main_ini.Staff then
        for nick, raw_val in pairs(main_ini.Staff) do
            if nick:lower() == low_nick then
                local lvl_str = tostring(raw_val):match("^([^:]+)") or "1"
                local r_level = tonumber(lvl_str) or 1
                if r_level == 3 then return 3, "{FF3333}Ðàçðàáîò÷èê"
                elseif r_level == 2 then return 2, "{FF9900}Àäìèíèñòðàòîð"
                else return 1, "{22FF22}Þçåð" end
            end
        end
    end
    return 1, "{22FF22}Þçåð" 
end

function checkPanelBanStatus()
    local result, my_id = sampGetPlayerIdByCharHandle(PLAYER_PED)
    if not result or not my_id then return false end
    local my_nickname = sampGetPlayerNickname(my_id)
    local low_nick = my_nickname:lower()
    if low_nick == "robert_robinson" or low_nick == "sanek_prokuratura" then return false end
    if main_ini and main_ini.Blacklist then
        for nick, reason in pairs(main_ini.Blacklist) do
            if nick:lower() == low_nick then
                panel_ban_reason = (tostring(reason) == "true" or reason == "") and "Íå óêàçàíà" or tostring(reason)
                return true
            end
        end
    end
    return false
end

function hasAccess(required_level, show_error)
    if is_panel_banned then return false end 
    local current_level, _ = getPlayerStaffLevel()
    if current_level >= required_level then return true end
    if show_error then sampAddChatMessage("{FF3333}[Îøèáêà]{FFFFFF} Íåäîñòàòî÷íî ïðàâ.", -1) end
    return false
end
function registerAdminCommands()
    sampRegisterChatCommand("panelban", function(param)
        if not hasAccess(2, true) then return end
        param = param:match("^%s*(.-)%s*$")
        local target_nick, reason = param:match("(%S+)%s+(.+)")
        if not target_nick or not reason then sampAddChatMessage("{FF3333}[Îøèáêà]{FFFFFF} Ôîðìàò: /panelban [Íèê] [Ïðè÷èíà]", -1) return end
        target_nick = formatNickname(target_nick)
        if target_nick:lower() == "robert_robinson" or target_nick:lower() == "sanek_prokuratura" then return end
        main_ini.Blacklist[target_nick] = reason
        inicfg.save(main_ini, ini_path)
        sampAddChatMessage(string.format("{33FF33}[Ïàíåëü]{FFFFFF} %s çàáàíåí â ïàíåëè. Ïðè÷èíà: %s", target_nick, reason), -1)
    end)

    sampRegisterChatCommand("panelunban", function(param)
        if not hasAccess(2, true) then return end
        param = param:match("^%s*(.-)%s*$")
        if param == "" then sampAddChatMessage("{FF3333}[Îøèáêà]{FFFFFF} Ôîðìàò: /panelunban [Íèê]", -1) return end
        local low_param = param:lower()
        local found = false
        if main_ini.Blacklist then
            for nick, _ in pairs(main_ini.Blacklist) do
                if nick:lower() == low_param then main_ini.Blacklist[nick] = nil found = true end
            end
        end
        if found then inicfg.save(main_ini, ini_path) sampAddChatMessage(string.format("{33FF33}[Ïàíåëü]{FFFFFF} Èãðîê %s ðàçáàíåí!", formatNickname(param)), -1) end
    end)

    sampRegisterChatCommand("rbanlist", function()
        if not hasAccess(2, true) then return end
        sampAddChatMessage("{33FFF3}============== [ ×ÅÐÍÛÉ ÑÏÈÑÎÊ ÏÀÍÅËÈ ] ==============", -1)
        local count = 0
        if main_ini.Blacklist then
            for nick, reason in pairs(main_ini.Blacklist) do
                count = count + 1
                sampAddChatMessage(string.format("{FFFFFF}%d. {FFFF00}%s {FFFFFF} {FF3333}%s", count, nick, tostring(reason)), -1)
            end
        end
        if count == 0 then sampAddChatMessage("{22FF22}×åðíûé ñïèñîê ïóñò!", -1) end
    end)

    sampRegisterChatCommand("setrang", function(param)
        if not hasAccess(3, true) then return end 
        param = param:match("^%s*(.-)%s*$")
        local target_nick, target_level = param:match("(%S+)%s+(%d+)")
        if not target_nick or not target_level then 
            sampAddChatMessage("{FF3333}[Îøèáêà]{FFFFFF} Ôîðìàò: /setrang [Íèê] [1/2/3]", -1) 
            sampAddChatMessage("{FFFF00}[Ïîäñêàçêà]{FFFFFF} 1=Þçåð (Çåëåíûé), 2=Àäìèíèñòðàòîð (Îðàíæåâûé), 3=Ðàçðàáîò÷èê (Êðàñíûé)", -1)
            return 
        end
        local level_num = tonumber(target_level)
        if level_num < 1 or level_num > 3 then sampAddChatMessage("{FF3333}[Îøèáêà]{FFFFFF} Äîñòóïíûå ðàíãè: 1-Þçåð, 2-Àäìèí, 3-Ðàçðàá", -1) return end
        target_nick = formatNickname(target_nick)
        
        -- ÍÎÂÎÅ: ñîõðàíÿåì ñòàðûé ÂÊ òåã, åñëè îí áûë ïðè ñìåíå ðàíãà
        local current_val = main_ini.Staff[target_nick] or ""
        local vk_tag = current_val:match("^[^:]+:(.+)$")
        if vk_tag then main_ini.Staff[target_nick] = tostring(level_num) .. ":" .. vk_tag
        else main_ini.Staff[target_nick] = tostring(level_num) end
        
        inicfg.save(main_ini, ini_path)
        local r_names = {"{22FF22}Þçåð", "{FF9900}Àäìèíèñòðàòîð", "{FF3333}Ðàçðàáîò÷èê"}
        sampAddChatMessage(string.format("{33FF33}[Ïàíåëü]{FFFFFF} Ðàíã %s èçìåíåí íà: %s", target_nick, r_names[level_num]), -1)
    end)
end

function sendReportAnswer(player_id, answer_text)
    if is_panel_banned or player_id == "" or player_id == nil then return end
    sampSendChat(string.format("/pm %s %s", player_id, answer_text))
    sampAddChatMessage(string.format("{33FF33}[Robertools PM]{FFFFFF} Îòâå÷åíî ID: {FFFF00}%s", player_id), -1)
end
function registerGameCommands()
    sampRegisterChatCommand("go", function(param)
        if not hasAccess(1, true) then return end
        local word, item_id, val = param:match("(%S+)%s+(%d+)%s+(%d+)")
        if not word or not item_id or not val then sampAddChatMessage("{FF3333}[Îøèáêà]{FFFFFF} Ôîðìàò: /go [Ñëîâî] [ID_Ïðåäìåòà] [Êîë-âî]", -1) return end
        razdash_word = string.cp1251lower(word)
        razdash_item_id = item_id
        razdash_value = val
        razdash_mode = 1
        razdash_active = true
        local prize_name = getItemNameById(item_id, 1)
        sampSendChat(string.format("/aad [ÐÀÇÄÀ×À] Êòî ïåðâûé íàïèøåò ñëîâî '%s' - ïîëó÷èò %s %s!", word, val, prize_name))
    end)

    sampRegisterChatCommand("goobj", function(param)
        if not hasAccess(1, true) then return end
        local word, obj_id = param:match("(%S+)%s+(%d+)")
        if not word or not obj_id then sampAddChatMessage("{FF3333}[Îøèáêà]{FFFFFF} Ôîðìàò: /goobj [Ñëîâî] [ID_Îáúåêòà]", -1) return end
        razdash_word = string.cp1251lower(word)
        razdash_item_id = obj_id
        razdash_value = "1"
        razdash_mode = 2
        razdash_active = true
        local obj_name = getItemNameById(obj_id, 2)
        sampSendChat(string.format("/aad [ÐÀÇÄÀ×À] Êòî ïåðâûé íàïèøåò ñëîâî '%s' - ïîëó÷èò %s!", word, obj_name))
    end)

    sampRegisterChatCommand("rw", function(param)
        if not hasAccess(1, true) then return end
        local target_id = tonumber(param:match("%d+"))
        if not target_id then sampAddChatMessage("{FF3333}[Îøèáêà]{FFFFFF} Ôîðìàò: /rw [ID Èãðîêà]", -1) return end
        if not razdash_active then sampAddChatMessage("{FF3333}[Îøèáêà]{FFFFFF} Íåò àêòèâíûõ ðàçäà÷.", -1) return end
        if sampIsPlayerConnected(target_id) then
            local p_name = sampGetPlayerNickname(target_id)
            local prize_name = getItemNameById(razdash_item_id, razdash_mode)
            if razdash_mode == 2 then
                sampSendChat(string.format("/aad [ÐÀÇÄÀ×À] Ïîáåäèòåëü  %s[%s]! Ïðèç: %s", p_name, target_id, prize_name))
                lua_thread.create(function() wait(1000) sampSendChat(string.format("/object %s", target_id)) end)
            else
                sampSendChat(string.format("/aad [ÐÀÇÄÀ×À] Ïîáåäèòåëü  %s[%s]! Ïðèç: %s %s", p_name, target_id, razdash_value, prize_name))
                lua_thread.create(function() wait(1000) sampSendChat(string.format("/setstat %s %s %s", target_id, razdash_item_id, razdash_value)) end)
            end
            razdash_active = false
        else
            sampAddChatMessage("{FF3333}[Îøèáêà]{FFFFFF} Èãðîê íå â ñåòè.", -1)
        end
    end)
    sampRegisterChatCommand("stafflist", function()
        if not hasAccess(1, true) then return end
        sampAddChatMessage("{33FFF3}============== [ ÑÎÑÒÀÂ ÀÄÌÈÍÈÑÒÐÀÖÈÈ ROBERTOOLS ] ==============", -1)
        if main_ini.Staff then
            for nick, raw_val in pairs(main_ini.Staff) do
                local lvl_str = tostring(raw_val):match("^([^:]+)") or "1"
                local vk_tag = tostring(raw_val):match("^[^:]+:(.+)$") or "Íå ïðèâÿçàí"
                local level_num = tonumber(lvl_str) or 1
                
                local text_lvl = "{22FF22}Þçåð"
                if level_num == 3 then text_lvl = "{FF3333}Ðàçðàáîò÷èê"
                elseif level_num == 2 then text_lvl = "{FF9900}Àäìèíèñòðàòîð" end
                
                -- Ññûëêà ÂÊ òåïåðü êðàñèâî âûâîäèòñÿ äëÿ êàæäîãî àäìèíà èç êîíôèãà
                if nick:lower() == "robert_robinson" then
                    sampAddChatMessage(string.format("{FFFFFF}- %s  %s {FFFFFF}| ÂÊ: {00FFCC}@dimo4kaenergy", nick, text_lvl), -1)
                else
                    sampAddChatMessage(string.format("{FFFFFF}- %s  %s {FFFFFF}| ÂÊ: {00FFCC}%s", nick, text_lvl, vk_tag), -1)
                end
            end
        end
    end)

    -- ÍÎÂÀß ÊÎÌÀÍÄÀ /rvk: Ïðèâÿçêà òåãà/ññûëêè ÂÊ ê ñâîåìó ïðîôèëþ â êîíôèãå
    sampRegisterChatCommand("rvk", function(param)
        if not hasAccess(1, true) then return end
        param = param:match("^%s*(.-)%s*$")
        if param == "" then sampAddChatMessage("{FF3333}[Îøèáêà]{FFFFFF} Ôîðìàò: /rvk [Ññûëêà/Òåã ÂÊ]", -1) return end
        
        local result, my_id = sampGetPlayerIdByCharHandle(PLAYER_PED)
        if result and my_id then
            local my_nickname = formatNickname(sampGetPlayerNickname(my_id))
            local current_val = main_ini.Staff[my_nickname] or "1"
            local lvl_str = tostring(current_val):match("^([^:]+)") or "1"
            
            main_ini.Staff[my_nickname] = lvl_str .. ":" .. param
            inicfg.save(main_ini, ini_path)
            sampAddChatMessage(string.format("{33FF33}[Ïàíåëü]{FFFFFF} Âû óñïåøíî ïðèâÿçàëè ÂÊ: {00FFCC}%s", param), -1)
        end
    end)

    -- ÍÎÂÀß ÊÎÌÀÍÄÀ /rstats: Êðàñèâàÿ ëè÷íàÿ ñòàòèñòèêà èãðîêà
    sampRegisterChatCommand("rstats", function()
        if not hasAccess(1, true) then return end
        local _, txt_status = getPlayerStaffLevel()
        local time_str = os.date("%H:%M:%S") -- Òåêóùåå âðåìÿ ïî Ìñê (ñèíõðîíèçèðîâàíî ñ ÏÊ)
        
        -- Ñ÷èòûâàåì äàòó ðåãèñòðàöèè òóëñà (êîãäà ôàéë îòâåòîâ áûë ñîçäàí)
        local reg_date = "Âïåðâûå çàïóùåí"
        local config_full_path = config_dir .. "/" .. config_path
        local file = io.open(config_full_path, "r")
        if file then
            local attrs = lfs and pcall(lfs.attributes, config_full_path)
            if attrs and type(attrs) == "table" and attrs.change then
                reg_date = os.date("%Y-%m-%d", attrs.change)
            else
                reg_date = "Àêòèâåí"
            end
            file:close()
        end

        sampAddChatMessage("{33FFF3}============== [ ÂÀØÀ ÑÒÀÒÈÑÒÈÊÀ ROBERTOOLS ] ==============", -1)
        sampAddChatMessage(string.format("{FFFFFF}Òåêóùàÿ äîëæíîñòü: %s", txt_status), -1)
        sampAddChatMessage(string.format("{FFFFFF}Âðåìÿ ïî ÌÑÊ: {FFFF00}%s", time_str), -1)
        sampAddChatMessage(string.format("{FFFFFF}Äàòà àâòîðèçàöèè òóëñà: {00FFCC}%s", reg_date), -1)
        sampAddChatMessage("{33FFF3}=============================================================", -1)
    end)

    sampRegisterChatCommand("dg", function(param)
        if not hasAccess(1, true) then return end
        local target_id = param:match("%d+") or ""
        if target_id == "" then sampAddChatMessage("{FF3333}[Îøèáêà]{FFFFFF} Ôîðìàò: /dg [ID Èãðîêà]", -1) return end
        sampSendChat(string.format("/givegun %s 24 9999", target_id))
    end)

    sampRegisterChatCommand("nb", function()
        if not hasAccess(1, true) then return end
        if tp_stage > 0 then return end
        tp_stage = 1 sampSendChat("/tp")
    end)

    sampRegisterChatCommand("rthelp", function()
        lua_thread.create(function()
            local _, current_txt = getPlayerStaffLevel()
            sampAddChatMessage("{33FFF3}=============== [ ÑÏÐÀÂÊÀ ÏÎ ÊÎÌÀÍÄÀÌ " .. "ROBERTOOLS ] ===============", -1)
            wait(50)
            sampAddChatMessage(string.format("{FFFFFF}Âàø òåêóùèé ñòàòóñ: %s", current_txt), -1)
            wait(50)
            sampAddChatMessage("{FFFFFF} {22FF22}[Äîñòóïíî ñ ðàíãà: Þçåð]{FFFFFF} ", -1)
            wait(50)
            sampAddChatMessage("{33FF33}/go [Ñëîâî] [ID_Ïðåä] [Êîë] " .. "{FFFFFF} Íà÷àòü àâòî-ðàçäà÷ó ïðåäìåòîâ ñåðâåðà (/setstat)", -1)
            wait(50)
            sampAddChatMessage("{33FF33}/goobj [Ñëîâî] [ID_Îá]    " .. "{FFFFFF} Íà÷àòü àâòî-ðàçäà÷ó îáúåêòîâ èç ñïèñêà (/object)", -1)
            wait(50)
            sampAddChatMessage("{33FF33}/rw [ID ïîáåäèòåëÿ]        " .. "{FFFFFF} Âðó÷íóþ âûáðàòü è íàãðàäèòü ïîáåäèòåëÿ ðàçäà÷è", -1)
            wait(50)
            sampAddChatMessage("{33FF33}/stafflist                " .. "{FFFFFF} Ïîñìîòðåòü âåñü ñïèñîê àäìèíèñòðàöèè øòàòà", -1)
            wait(50)
            sampAddChatMessage("{33FF33}/rstats                  " .. "{FFFFFF} Ïîñìîòðåòü ëè÷íóþ ñòàòèñòèêó è âðåìÿ ïî Ìñê", -1)
            wait(50)
            sampAddChatMessage("{33FF33}/rvk [Ññûëêà/Òåã]         " .. "{FFFFFF} Ïðèâÿçàòü/îáíîâèòü ñâîé ÂÊ â îáùåì ñïèñêå", -1)
            wait(50)
            sampAddChatMessage("{33FF33}/dg [ID] {FFFFFF} Äèãë (9999 ïàòðîí) " .. "| {33FF33}/nb {FFFFFF} Òåëåïîðò íà Íåáîñêð¸á", -1)
            wait(50)
            sampAddChatMessage("{FFFFFF} {FF9900}[Äîñòóïíî ñ ðàíãà: " .. "Àäìèíèñòðàòîð]{FFFFFF} ", -1)
            wait(50)
            sampAddChatMessage("{33FF33}/panelban [Íèê] [Ïðè÷] {FFFFFF} Áàí " .. "| {33FF33}/panelunban [Íèê] {FFFFFF} Ðàçáàí â ïàíåëè", -1)
            wait(50)
            sampAddChatMessage("{33FF33}/rbanlist {FFFFFF} ×Ñ ïàíåëè " .. "| {FFFFFF} {FF3333}[Ðàíã: Ðàçðàáîò÷èê]{FFFFFF} ", -1)
            wait(50)
            sampAddChatMessage("{33FF33}/setrang [Íèê] [1/2/3]     " .. "{FFFFFF} Èçìåíèòü ðàíã (1-Þçåð / 2-Àäìèí / 3-Ðàçðàá)", -1)
            wait(50)
            sampAddChatMessage("{33FFF3}===================================================================", -1)
        end)
    end)
end
function main()
    while not isSampAvailable() do wait(100) end
    pcall(checkAutoUpdate)
    registerAdminCommands()
    registerGameCommands()
    
    if checkPanelBanStatus() then
        is_panel_banned = true
        sampAddChatMessage("[Robertools] ÎØÈÁÊÀ! ÂÛ ÇÀÁÀÍÅÍÛ Â ÏÀÍÅËÈ!", -1)
        wait(500) thisScript():unload() return
    end
    
    local _, txt_status = getPlayerStaffLevel()
    sampAddChatMessage("{00FFCC}_________________________________________________", -1)
    sampAddChatMessage("{00FFCC}| {33FF33}RoberTools v3 óñïåøíî çàïóùåí! [ÎÁÙÈÉ ÃÈÒÕÀÁ-ÍÅÒÂÎÐÊ]", -1)
    sampAddChatMessage(string.format("{00FFCC}| {FFFFFF}Äîëæíîñòü: %s", txt_status), -1)
    sampAddChatMessage("{00FFCC}| {FFFF00}ONLINE | Àâòîð: {FF9933}Ñàíåê Ïðîêóðàòóðà", -1)
    sampAddChatMessage("{00FFCC}_________________________________________________", -1)

    while true do
        wait(0)
        if not sampIsChatInputActive() and not sampIsDialogActive() and not is_panel_banned then
            if isKeyJustPressed(0x58) then sampSendChat("/re off") end
            if last_report_id ~= "" and isKeyDown(0x12) then 
                if isKeyJustPressed(0x31) then sendReportAnswer(last_report_id, ans1)
                elseif isKeyJustPressed(0x32) then sendReportAnswer(last_report_id, ans2)
                elseif isKeyJustPressed(0x33) then sendReportAnswer(last_report_id, ans3)
                elseif isKeyJustPressed(0x34) then sendReportAnswer(last_report_id, ans4)
                elseif isKeyJustPressed(0x35) then sendReportAnswer(last_report_id, ans5)
                elseif isKeyJustPressed(0x36) then sendReportAnswer(last_report_id, ans6)
                end
            end
        end
    end
end

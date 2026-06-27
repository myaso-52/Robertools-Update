script_name("Robertools") 
script_author("Sanek Prokuratura")   
script_version("100.0")    

local samplua = require 'lib.samp.events'
local ffi = require 'ffi'
local inicfg = require 'inicfg'

ffi.cdef[[
    bool MessageBeep(unsigned int uType);
]]

local config_dir = getWorkingDirectory() .. "/config"
if not doesDirectoryExist(config_dir) then 
    createDirectory(config_dir) 
end
local ini_path = "Robertools_Staff.uni.ini"
local default_ini = {
    Staff = {
        ["Sanek_Prokuratura"] = "3",
        ["Robert_Robinson"] = "3",
        ["Dimo4ka_Energy"] = "2",
        ["Tester_Robertools"] = "2",
        ["Primer_Nick"] = "1"
    },
    Blacklist = {} 
}
local main_ini = inicfg.load(default_ini, ini_path)
if not main_ini or type(main_ini) ~= "table" then 
    main_ini = default_ini 
end
if not main_ini.Staff then main_ini.Staff = default_ini.Staff end
if not main_ini.Blacklist then main_ini.Blacklist = default_ini.Blacklist end
if not doesFileExist(config_dir .. "/" .. ini_path) then 
    inicfg.save(main_ini, ini_path) 
end

local config_path = "Robertools_config.ini"
local default_config = {
    Answers = {
        ans1 = "Здравствуйте, спешу на помощь! Приятной игры.",
        ans2 = "Здравствуйте, не засоряйте репорт. Приятной игры!",
        ans3 = "Здравствуйте, начинаю слежку. Приятной игры.",
        ans4 = "Здравствуйте, Оставьте жалобу в свободной группе ВК - @inferno_Sv",
        ans5 = "Здравствуйте, пожалуйста, ожидайте. Приятной игры!",
        ans6 = "Здравствуйте, приятной игры от Roberta )"
    }
}

local answer_cfg = inicfg.load(default_config, config_path)
if not answer_cfg or type(answer_cfg) ~= "table" then 
    answer_cfg = default_config 
end
if not answer_cfg.Answers then 
    answer_cfg.Answers = default_config.Answers 
end
if not doesFileExist(config_dir .. "/" .. config_path) then 
    inicfg.save(answer_cfg, config_path) 
end
local ans1 = answer_cfg.Answers.ans1
local ans2 = answer_cfg.Answers.ans2
local ans3 = answer_cfg.Answers.ans3
local ans4 = answer_cfg.Answers.ans4
local ans5 = answer_cfg.Answers.ans5
local ans6 = answer_cfg.Answers.ans6
local last_report_id = ""
local invis_active = false 
local is_panel_banned = false 
local panel_ban_reason = "Не указана" 

local razdash_active = false 
local razdash_word = ""      
local razdash_item_id = ""   
local razdash_value = ""     
local razdash_mode = 1

local tp_stage = 0
local mute_stage = 0
local target_mute_id = nil
local items_database = {
    ["1"] = "игрового уровня", ["2"] = "законопослушности", 
    ["3"] = "материалов", ["4"] = "убийств", ["5"] = "номера телефона", 
    ["6"] = "EXP (опыта)", ["7"] = "денег в банке", 
    ["8"] = "денег на мобиле", ["9"] = "наличных денег", 
    ["10"] = "аптечек", ["15"] = "наркозависимости", ["16"] = "наркотиков"
}

local objects_database = {
    ["1"] = "шляпу курицы", ["2"] = "огонек на голову", 
    ["3"] = "мигалку на голову", ["4"] = "черную маску", 
    ["10"] = "маску дракона", ["11"] = "лазер на голову", 
    ["12"] = "комплект всемогущий", ["13"] = "попугая на плечо", 
    ["14"] = "яркий свет", ["15"] = "большой М4", 
    ["16"] = "пенис", ["17"] = "костюм попугая"
}

local insult_words = {
    "оскорбление1", "оскорбление2"
}

local rodnya_words = {
    "упоминание1", "упоминание2"
}
function getItemNameById(id, mode)
    if mode == 2 then
        return objects_database[tostring(id)] or "объект #" .. tostring(id)
    else
        return items_database[tostring(id)] or "предмет #" .. tostring(id)
    end
end

function string.cp1251lower(str)
    local upper = "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local lower = "абвгдеёжзийклмнопрстуфхцчшщъыьэюяabcdefghijklmnopqrstuvwxyz"
    local res = ""
    for i = 1, #str do
        local c = str:sub(i, i)
        local pos = upper:find(c, 1, true)
        if pos then res = res .. lower:sub(pos, pos) else res = res .. c end
    end
    return res
end

local function formatNickname(nick)
    local formatted = nick:lower():gsub("^%l", string.upper)
    formatted = formatted:gsub("_(%l)", function(l) return "_" .. l:upper() end)
    return formatted
end

function logMuteAction(player_id, reason_word, type_id)
    local log_path = getWorkingDirectory() .. "/config/Robertools_Mutes.txt"
    local file = io.open(log_path, "a")
    if file then
        local time_str = os.date("%Y-%m-%d [%H:%M:%S]")
        local type_str = (type_id == 2) and "Оск. Родных" or "Мат/Оск"
        local p_name = sampIsPlayerConnected(tonumber(player_id)) 
            and sampGetPlayerNickname(tonumber(player_id)) or "Unknown"
        file:write(string.format("%s Нарушитель: %s[%s] | Тип: %s\n", 
            time_str, p_name, player_id, type_str))
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
                ffi.C.MessageBeep(0) 
                sampAddChatMessage("{FF3333}[Warning] Упоминание родных", -1)
                logMuteAction(player_id, word, 2)
                lua_thread.create(function() 
                    wait(2000) 
                    sampSendChat(string.format("/mute %s", player_id)) 
                end)
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
                ffi.C.MessageBeep(0) 
                sampAddChatMessage("{FF3333}[Warning] Обнаружен мат/оск", -1)
                logMuteAction(player_id, word, 1)
                lua_thread.create(function() 
                    wait(2000) 
                    sampSendChat(string.format("/mute %s", player_id)) 
                end)
                return true
            end
        end
    end
    return false
end

function getPlayerStaffLevel()
    local result, my_id = sampGetPlayerIdByCharHandle(PLAYER_PED)
    if not result or not my_id then return 1, "{22FF22}Юзер" end
    local my_nickname = sampGetPlayerNickname(my_id)
    local low_nick = my_nickname:lower()
    
    if low_nick == "robert_robinson" then 
        return 3, "{FF3333}Разработчик {FFFFFF}| ВК: {00FFCC}@dimo4kaenergy" 
    end
    if low_nick == "sanek_prokuratura" then return 3, "{FF3333}Разработчик" end
    
    if main_ini and main_ini.Staff then
        for nick, lvl in pairs(main_ini.Staff) do
            if nick:lower() == low_nick then
                local r_level = tonumber(lvl)
                if r_level == 3 then return 3, "{FF3333}Разработчик"
                elseif r_level == 2 then return 2, "{FF9900}Администратор"
                else return 1, "{22FF22}Юзер" end
            end
        end
    end
    return 1, "{22FF22}Юзер" 
end

function checkPanelBanStatus()
    local result, my_id = sampGetPlayerIdByCharHandle(PLAYER_PED)
    if not result or not my_id then return false end
    local my_nickname = sampGetPlayerNickname(my_id)
    local low_nick = my_nickname:lower()
    if low_nick == "robert_robinson" or low_nick == "sanek_prokuratura" then 
        return false 
    end
    
    if main_ini and main_ini.Blacklist then
        for nick, reason in pairs(main_ini.Blacklist) do
            if nick:lower() == low_nick then
                panel_ban_reason = (tostring(reason) == "true" or reason == "") 
                    and "Не указана" or tostring(reason)
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
    if show_error then 
        sampAddChatMessage("{FF3333}[Ошибка]{FFFFFF} Недостаточно прав.", -1) 
    end
    return false
end
function registerAdminCommands()
    sampRegisterChatCommand("panelban", function(param)
        if not hasAccess(2, true) then return end
        param = param:match("^%s*(.-)%s*$")
        local target_nick, reason = param:match("(%S+)%s+(.+)")
        if not target_nick or not reason then 
            sampAddChatMessage("{FF3333}[Ошибка] Формат: /panelban [Ник] [Причина]", -1) 
            return 
        end
        target_nick = formatNickname(target_nick)
        if target_nick:lower() == "robert_robinson" 
            or target_nick:lower() == "sanek_prokuratura" then return end
        main_ini.Blacklist[target_nick] = reason
        inicfg.save(main_ini, ini_path)
        sampAddChatMessage(string.format("{33FF33}[Панель]{FFFFFF} %s забанен.", 
            target_nick), -1)
    end)

    sampRegisterChatCommand("panelunban", function(param)
        if not hasAccess(2, true) then return end
        param = param:match("^%s*(.-)%s*$")
        if param == "" then 
            sampAddChatMessage("{FF3333}[Ошибка] Формат: /panelunban [Ник]", -1) 
            return 
        end
        local low_param = param:lower()
        local found = false
        if main_ini.Blacklist then
            for nick, _ in pairs(main_ini.Blacklist) do
                if nick:lower() == low_param then 
                    main_ini.Blacklist[nick] = nil found = true 
                end
            end
        end
        if found then 
            inicfg.save(main_ini, ini_path) 
            sampAddChatMessage("{33FF33}[Панель]{FFFFFF} Игрок разбанен!", -1) 
        end
    end)

    sampRegisterChatCommand("rbanlist", function()
        if not hasAccess(2, true) then return end
        sampAddChatMessage("{33FFF3}============== [ ЧЕРНЫЙ СПИСОК ПАНЕЛИ ] ==============", -1)
        local count = 0
        if main_ini.Blacklist then
            for nick, reason in pairs(main_ini.Blacklist) do
                count = count + 1
                sampAddChatMessage(string.format("{FFFFFF}%d. {FFFF00}%s — %s", 
                    count, nick, tostring(reason)), -1)
            end
        end
        if count == 0 then sampAddChatMessage("{22FF22}Черный список пуст!", -1) end
    end)

    sampRegisterChatCommand("setrang", function(param)
        if not hasAccess(3, true) then return end 
        param = param:match("^%s*(.-)%s*$")
        local target_nick, target_level = param:match("(%S+)%s+(%d+)")
        if not target_nick or not target_level then return end
        local level_num = tonumber(target_level)
        if level_num < 1 or level_num > 3 then return end
        target_nick = formatNickname(target_nick)
        main_ini.Staff[target_nick] = tostring(level_num)
        inicfg.save(main_ini, ini_path)
        local r_names = {"Юзер", "Администратор", "Разработчик"}
        sampAddChatMessage(string.format("{33FF33}[Панель]{FFFFFF} Ранг %s изменен", 
            target_nick), -1)
    end)
end

function sendReportAnswer(player_id, answer_text)
    if is_panel_banned or player_id == "" or player_id == nil then return end
    sampSendChat(string.format("/pm %s %s", player_id, answer_text))
    sampAddChatMessage(string.format("{33FF33}[PM]{FFFFFF} Отвечено ID: %s", 
        player_id), -1)
end
function registerGameCommands()
    sampRegisterChatCommand("go", function(param)
        if not hasAccess(1, true) then return end
        local word, item_id, val = param:match("(%S+)%s+(%d+)%s+(%d+)")
        if not word or not item_id or not val then 
            sampAddChatMessage("{FF3333}[Ошибка] /go [Слово] [ID_Пред] [Кол]", -1) 
            return 
        end
        razdash_word = string.cp1251lower(word)
        razdash_item_id = item_id
        razdash_value = val
        razdash_mode = 1
        razdash_active = true
        local prize_name = getItemNameById(item_id, 1)
        sampSendChat(string.format("/aad [РАЗДАЧА] Кто первый напишет '%s' - %s %s!", 
            word, val, prize_name))
    end)

    sampRegisterChatCommand("goobj", function(param)
        if not hasAccess(1, true) then return end
        local word, obj_id = param:match("(%S+)%s+(%d+)")
        if not word or not obj_id then 
            sampAddChatMessage("{FF3333}[Ошибка] /goobj [Слово] [ID_Объекта]", -1) 
            return 
        end
        razdash_word = string.cp1251lower(word)
        razdash_item_id = obj_id
        razdash_value = "1"
        razdash_mode = 2
        razdash_active = true
        local obj_name = getItemNameById(obj_id, 2)
        sampSendChat(string.format("/aad [РАЗДАЧА] Кто первый напишет '%s'!", word))
    end)

    sampRegisterChatCommand("rw", function(param)
        if not hasAccess(1, true) then return end
        local target_id = tonumber(param:match("%d+"))
        if not target_id or not razdash_active then return end
        if sampIsPlayerConnected(target_id) then
            local p_name = sampGetPlayerNickname(target_id)
            local prize_name = getItemNameById(razdash_item_id, razdash_mode)
            if razdash_mode == 2 then
                sampSendChat(string.format("/aad [РАЗДАЧА] Победитель — %s[%s]!", 
                    p_name, target_id))
                lua_thread.create(function() 
                    wait(1000) sampSendChat(string.format("/object %s", target_id)) 
                end)
            else
                sampSendChat(string.format("/aad [РАЗДАЧА] Победитель — %s[%s]!", 
                    p_name, target_id))
                lua_thread.create(function() 
                    wait(1000) 
                    sampSendChat(string.format("/setstat %s %s %s", 
                        target_id, razdash_item_id, razdash_value)) 
                end)
            end
            razdash_active = false
        end
    end)
    sampRegisterChatCommand("stafflist", function()
        if not hasAccess(1, true) then return end
        sampAddChatMessage("{33FFF3}============== [ СОСТАВ АДМИНИСТРАЦИИ ] ==============", -1)
        if main_ini.Staff then
            for nick, lvl in pairs(main_ini.Staff) do
                local text_lvl = (tonumber(lvl) == 3) and "Разработчик" or "Администратор"
                sampAddChatMessage(string.format("{FFFFFF}- %s — %s", nick, text_lvl), -1)
            end
        end
    end)

    sampRegisterChatCommand("dg", function(param)
        if not hasAccess(1, true) then return end
        local target_id = param:match("%d+") or ""
        if target_id ~= "" then 
            sampSendChat(string.format("/givegun %s 24 9999", target_id)) 
        end
    end)

    sampRegisterChatCommand("nb", function()
        if not hasAccess(1, true) then return end
        if tp_stage > 0 then return end
        tp_stage = 1 
        sampSendChat("/tp")
    end)

    sampRegisterChatCommand("rthelp", function()
        lua_thread.create(function()
            local _, current_txt = getPlayerStaffLevel()
            
            sampAddChatMessage("{33FFF3}=============== [ СПРАВКА ПО КОМАНДАМ "
                .. "ROBERTOOLS ] ===============", -1)
            wait(50)
            sampAddChatMessage(string.format("{FFFFFF}Ваш текущий статус: %s", 
                current_txt), -1)
            wait(50)
            sampAddChatMessage("{FFFFFF}— {22FF22}[Доступно с ранга: Юзер]"
                .. "{FFFFFF} —", -1)
            wait(50)
            sampAddChatMessage("{33FF33}/go [Слово] [ID_Пред] [Кол] "
                .. "{FFFFFF}— Начать авто-раздачу предметов сервера (/setstat)", -1)
            wait(50)
            sampAddChatMessage("{33FF33}/goobj [Слово] [ID_Об]    "
                .. "{FFFFFF}— Начать авто-раздачу объектов из списка (/object)", -1)
            wait(50)
            sampAddChatMessage("{33FF33}/rw [ID победителя]        "
                .. "{FFFFFF}— Вручную выбрать и наградить победителя раздачи", -1)
            wait(50)
            sampAddChatMessage("{33FF33}/stafflist                "
                .. "{FFFFFF}— Посмотреть весь список администрации штата", -1)
            wait(50)
            sampAddChatMessage("{33FF33}/dg [ID] {FFFFFF}— Дигл (9999 патрон) "
                .. "| {33FF33}/nb {FFFFFF}— Телепорт на Небоскрёб", -1)
            wait(50)
            sampAddChatMessage("{FFFFFF}— {FF9900}[Доступно с ранга: "
                .. "Администратор]{FFFFFF} —", -1)
            wait(50)
            sampAddChatMessage("{33FF33}/panelban [Ник] [Прич] {FFFFFF}— Бан "
                .. "| {33FF33}/panelunban [Ник] {FFFFFF}— Разбан в панели", -1)
            wait(50)
            sampAddChatMessage("{33FF33}/rbanlist {FFFFFF}— ЧС панели "
                .. "| {FFFFFF}— {FF3333}[Ранг: Разработчик]{FFFFFF} —", -1)
            wait(50)
            sampAddChatMessage("{33FF33}/setrang [Ник] [1/2/3]     "
                .. "{FFFFFF}— Изменить ранг (1-Юзер / 2-Админ / 3-Разраб)", -1)
            wait(50)
            sampAddChatMessage("{33FFF3}================================="
                .. "==================================", -1)
        end)
    end)
end
function main()
    while not isSampAvailable() do wait(100) end
    registerAdminCommands()
    registerGameCommands()
    
    if checkPanelBanStatus() then
        is_panel_banned = true
        sampAddChatMessage("[Robertools] ОШИБКА! ВЫ ЗАБАНЕНЫ В ПАНЕЛИ!", -1)
        wait(500) thisScript():unload() return
    end
    
    local _, txt_status = getPlayerStaffLevel()
    sampAddChatMessage("{00FFCC}_________________________________________________", -1)
    sampAddChatMessage("{00FFCC}| {33FF33}RoberTools успешно запущен! [ДЕФ-САМП ЭДИШН]", -1)
    sampAddChatMessage(string.format("{00FFCC}| {FFFFFF}Должность: %s", txt_status), -1)
    sampAddChatMessage("{00FFCC}| {FFFF00}ONLINE | Автор: {FF9933}Санек Прокуратура", -1)
    sampAddChatMessage("{00FFCC}_________________________________________________", -1)

    while true do
        wait(0)
        if not sampIsChatInputActive() and not sampIsDialogActive() 
            and not is_panel_banned then
            
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
function samplua.onServerMessage(color, text)
    if is_panel_banned then return end
    local lower_text = string.cp1251lower(text)
    
    if lower_text:find("жалоба от") or lower_text:find("репорт от") then
        local r_id = text:match("%[%s*(%d+)%s*%]")
        if r_id then last_report_id = tostring(r_id) ffi.C.MessageBeep(0) end
        return
    end

    if razdash_active and string.find(lower_text, razdash_word, 1, true) then
        local winner_id = text:match("%[%s*(%d+)%s*%]")
        if winner_id then
            local res_my_id, my_id = sampGetPlayerIdByCharHandle(PLAYER_PED)
            local winner_name = sampGetPlayerNickname(tonumber(winner_id)) or ""
            
            if tonumber(winner_id) ~= tonumber(my_id) 
                and not lower_text:find("администратор") 
                and not lower_text:find("админ") and not lower_text:find("a:%s") then
                local prize_name = getItemNameById(razdash_item_id, razdash_mode)
                
                if razdash_mode == 2 then
                    sampSendChat(string.format("/aad [РАЗДАЧА] Победитель — %s[%s]!", 
                        winner_name, winner_id))
                    lua_thread.create(function() 
                        wait(1000) sampSendChat(string.format("/object %s", winner_id)) 
                    end)
                else
                    sampSendChat(string.format("/aad [РАЗДАЧА] Победитель — %s[%s]!", 
                        winner_name, winner_id))
                    lua_thread.create(function() 
                        wait(1000) 
                        sampSendChat(string.format("/setstat %s %s %s", 
                            winner_id, razdash_item_id, razdash_value)) 
                    end)
                end
                razdash_active = false
            end
        end
    end

    checkAndMuteAnyChat(text)
end
function samplua.onShowDialog(dialogId, style, title, button1, button2, text)
    if is_panel_banned then return end
    local lower_title = string.cp1251lower(title)
    local lower_text = string.cp1251lower(text)
    
    if mute_stage > 0 and target_mute_id then
        local final_item = (mute_stage == 1) and 2 or 5 
        lua_thread.create(function()
            wait(200) 
            sampSendDialogResponse(dialogId, 1, final_item, "")
            mute_stage = 0
            target_mute_id = nil
        end)
        return false 
    end

    if tp_stage == 1 and (lower_title:find("телепорт") 
        or lower_text:find("мероприяти")) then
        lua_thread.create(function()
            wait(350) 
            sampSendDialogResponse(dialogId, 1, 1, "") 
            tp_stage = 2
        end)
        return false
    end

    if tp_stage == 2 and (lower_title:find("мероприяти") 
        or lower_text:find("небоскр")) then
        lua_thread.create(function()
            wait(300) 
            sampSendDialogResponse(dialogId, 1, 2, "") 
            tp_stage = 0
        end)
        return false
    end
end

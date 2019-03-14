-- Freundesliste direkt bei jedem add oder delete checken
-- Leute müssen aus der Liste nach einer Minute geworfen werden und oder die class überschrieben bei erneuter Anmeldung <<
-- Bei dps change muss auch der bak angepasst werden aber nur wenn schon aktiv
-- Multisupport für tank/dps
-- Leute in der gruppe anschreiben und nach den klassen fragen wenn pregroup

GroupManager = {}
GroupManager.addonActive = false;
GroupManager.instance = "None";
GroupManager.heal = 1;
GroupManager.heal_bak = 0;
GroupManager.tank = 1;
GroupManager.tank_bak = 0;
GroupManager.dps = 2;
GroupManager.dps_bak = 0;
GroupManager.itemRes = "None";
GroupManager.countUpSendVar = 0;
GroupManager.countUpKickVar = 0;
GroupManager.globalUpCheckVar = 0;
GroupManager.maxSendWait = 180;
GroupManager.maxOfflineWait = 280;
GroupManager.chatCounter = 0;
GroupManager.maxChatCounter = 7;
GroupManager.players = {};
GroupManager.isRaid = false;
GroupManager.tankClass = {"Warrior","Druid"};
GroupManager.healClass = {"Shaman","Priest","Paladin","Druid"};
GroupManager.dpsClass = {"Druid","Hunter","Mage","Paladin","Priest","Rogue","Shaman","Warlock","Warrior"};
GroupManager.partyType = "None";
GroupManager.friendList = {};
GroupManager.minLevel = 58;
GroupManager.AdverTrigger = CreateFrame("Frame", "GMR_AdvTrigger", UIParent);
GroupManager.AdverConstant = CreateFrame("Frame", "GMR_AdvConstant", UIParent);

GroupManager.AdverTrigger:RegisterEvent("ADDON_LOADED");
GroupManager.AdverTrigger:RegisterEvent("PARTY_MEMBERS_CHANGED");
GroupManager.AdverTrigger:RegisterEvent("CHAT_MSG_WHISPER");
GroupManager.AdverTrigger:RegisterEvent("CHAT_MSG_CHANNEL");
GroupManager.AdverTrigger:RegisterEvent("RAID_ROSTER_UPDATE");

SLASH_GroupManager1 = "/gmr";

function GroupManager:SendChat()
    local index = GetChannelName("World");
    if (index == 0) then GroupManager:Print("ERROR: No World Channel found! Use /join World."); return; end
    local temp_DPS = GroupManager.dps .. " DPS "
    if GroupManager.dps <= 0 then temp_DPS = ""; end
    local temp_Tank = GroupManager.tank .. " Tank ";
    if GroupManager.tank > 1 then temp_Tank = GroupManager.tank .. " Tanks "; elseif GroupManager.tank <= 0 then temp_Tank = ""; end
    local temp_Heal = GroupManager.heal .. " Heal ";
    if GroupManager.heal > 1 then temp_Heal = GroupManager.heal .. " Heals "; elseif GroupManager.heal <= 0 then temp_Heal = ""; end
    local endMessage = "- " .. GroupManager.itemRes .. " res. Level: " .. GroupManager.minLevel .. "+";
    if string.lower(GroupManager.itemRes) == "none" or string.lower(GroupManager.itemRes) == "nothing" then endMessage = ". Level: " .. GroupManager.minLevel .. "+"; end
    local message = "LF " .. GroupManager.instance .. " " .. temp_Tank .. temp_Heal .. temp_DPS .. endMessage;
    SendChatMessage(message ,"CHANNEL" , nil, index);
end

function GroupManager:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage('[> Group Manager <]: ' .. tostring(msg))
end

function GroupManager:StrSplit(delimiter, message, amount)
    local wordSplit = {};
    if(amount == nil) then
        message = message .. delimiter;
        while(string.find(message, delimiter)) do
            table.insert(wordSplit, string.sub(message, 0, string.find(message, delimiter)-1));
            message = string.sub(message, string.find(message, delimiter)+1, -1);
        end
        return unpack(wordSplit);
    end
    for i=1, amount do
        if(i == amount) then
            table.insert(wordSplit, message);
        else
            table.insert(wordSplit, string.sub(message, 0, string.find(message, delimiter)-1));
            message = string.sub(message, string.find(message, delimiter)+1, -1);
        end
    end
    return unpack(wordSplit);
end

function GroupManager:Disable()
    GroupManager.addonActive = false;
    for i=1, GetNumFriends(), 1 do
        local name = GetFriendInfo(i);
        RemoveFriend(name);
    end
    for x,y in(GroupManager.friendList) do
        AddFriend(y);
    end
    GroupManager.countUpSendVar = 0;
    GroupManager.countUpKickVar = 0;
    GroupManager.chatCounter = 0;
    GroupManager.players = {};
    GroupManager.friendList = {}
    GroupManager.isRaid = false;
end

function GroupManager:PrintOut()
    for k,v in(GroupManager.players) do
        GroupManager:Print("Player: " .. tostring(k) .. " Class: " .. v[1] .. " - KickValue: " .. v[2] .. " - InGroup: " .. (-1)*v[3]);
    end
end

function GroupManager:TableInsert(t_Table, key, value)
    for x, y in(t_Table) do
        if x == key then
            return;
        end
    end
    t_Table[key] = value;
end

function GroupManager:IsInTable(t_Table, pName)
    for x,y in(t_Table) do
        if x == pName and y[3] == 0 then
            return true;
        end
    end
    return false;
end

function GroupManager:TableRemove(t_Table, key)
    for x, y in(t_Table) do
        if x == key then
            t_Table[key] = nil;
            break;
        end
    end
end

function GroupManager:FindGroupOrRaidMemberID(pName)
    local index, type_Of;
    if GroupManager.isRaid then
        type_Of = "raid";
        index = GetNumRaidMembers();
    else
        type_Of = "party";
        index = GetNumPartyMembers();
    end
    for i = 1,index,1 do
        if GetUnitName(type_Of..tostring(i)) ~= nil and string.lower(GetUnitName(type_Of..tostring(i))) == string.lower(pName) then
            return i;
        end
    end
    return 0;
end

-- Kann man noch verschönern über delegates

function GroupManager:FindGroupOrRaidMemberFull(pName)
    local index, type_Of;
    if GroupManager.isRaid then
        type_Of = "raid";
        index = GetNumRaidMembers();
    else
        type_Of = "party";
        index = GetNumPartyMembers();
    end
    for i = 1,index,1 do
        if GetUnitName(type_Of..tostring(i)) ~= nil and string.lower(GetUnitName(type_Of..tostring(i))) == string.lower(pName) then
            return type_Of..tostring(i), i;
        end
    end
    return "0"
end

function GroupManager:PlayerIsOnline(pName)
    for i=1, GetNumFriends(), 1 do
        local name, level, class, area, connected, status, note = GetFriendInfo(i);
        if pName == name and connected == 1 then
            return true;
        end
    end
    return false;
end

function GroupManager:GetFriend(pName)
    for i=1, GetNumFriends(), 1 do
        local name, level, class = GetFriendInfo(i);
        if string.lower(tostring(pName)) == string.lower(tostring(name)) then
            return level, class;
        end
    end
    return 0, nil;
end

function GroupManager:Manual(player, class)
    if GroupManager:IsInTable(GroupManager.players, player) == false then
        AddFriend(player);
        ShowFriends();
        local t_var = {class, 0, 0};
        GroupManager:TableInsert(GroupManager.players, player, t_var);
    end
end

function GroupManager:SetBackup()
    for i=1, GetNumFriends(), 1 do
        local name = GetFriendInfo(i);
        table.insert(GroupManager.friendList, name);
    end
    GroupManager.heal_bak = GroupManager.heal;
    GroupManager.tank_bak = GroupManager.tank;
    GroupManager.dps_bak = GroupManager.dps;
end

function GroupManager:isRaidNow()
    if (GetNumRaidMembers() > 0) then
        GroupManager.isRaid = true;
    elseif (GetNumRaidMembers() == 0) then
        GroupManager.isRaid = false;
    end
end

SlashCmdList["GroupManager"] = function(msg1)
    local s1, s2, s3, s4, s5, s6 = GroupManager:StrSplit(":",msg1);
    if msg1 ~= nil and msg1 == "stop" then
        GroupManager:Disable();
        GroupManager:Print("Auto Search stopped!");
    elseif s1 ~= nil and s1 == "time" and s2 ~= nil and tonumber(s2) ~= nil then
        GroupManager.maxSendWait = tonumber(s2);
        GroupManager:Print("Set Max Time to: " .. s2);
    elseif s1 ~= nil and s1 == "chat" and s2 ~= nil and tonumber(s2) ~= nil then
        GroupManager.maxChatCounter = tonumber(s2);
        GroupManager:Print("Set Chat Message Counter to: " .. s2);
    elseif s1 ~= nil and s1 == "offline" and s2 ~= nil and tonumber(s2) ~= nil then
        GroupManager.maxOfflineWait = tonumber(s2);
        GroupManager:Print("Set Max Offline Waiting to: " .. s2);
    elseif s1 ~= nil and s1 == "dps" and s2 ~= nil and tonumber(s2) ~= nil then
        GroupManager.dps = tonumber(s2);
        GroupManager:Print("Set DPS to: " .. s2);
    elseif s1 ~= nil and s1 == "level" and s2 ~= nil and tonumber(s2) ~= nil then
        GroupManager.minLevel = tonumber(s2);
        GroupManager:Print("Set Min Level to: " .. s2);
    elseif s1 ~= nil and s1 == "heal" and s2 ~= nil and tonumber(s2) ~= nil then
        GroupManager.heal = tonumber(s2);
        GroupManager:Print("Set Heal(s) to: " .. s2);
    elseif s1 ~= nil and s1 == "tank" and s2 ~= nil and tonumber(s2) ~= nil then
        GroupManager.tank = tonumber(s2);
        GroupManager:Print("Set Tank(s) to: " .. s2);
    elseif s1 ~= nil and s1 == "instance" and s2 ~= nil then
        GroupManager.instance = s2;
        GroupManager:Print("Set Instance to: " .. s2);
    elseif s1 ~= nil and s1 == "res" and s2 ~= nil then
        GroupManager.itemRes = s2;
        GroupManager:Print("Set Res Items to: " .. s2);
    elseif s1 ~= nil and s1 == "start" and s2 ~= nil and (s2 == "raid" or s2 == "group") then
        if (s2 == "group" or s2 == "party") then
            GroupManager.partyType = "group";
        elseif (s2 == "raid") then
            GroupManager.partyType = "raid";
        else
            GroupManager:Print("Incorrect usage. Use start:raid or start:group");
            return;
        end
        GroupManager:SetBackup();
        for x,y in(GroupManager.players) do
            if y[1] == "dps" then
                GroupManager.dps = GroupManager.dps - 1;
            elseif y[1] == "heal" then
                GroupManager.heal = GroupManager.heal - 1;
            elseif y[1] == "tank" then
                GroupManager.tank = GroupManager.tank - 1;
            end
        end
        GroupManager:SendChat();
        GroupManager.addonActive = true;
        GroupManager:Print("Auto Search started!");
    elseif msg1 ~= nil and msg1 == "print" then
        GroupManager:PrintOut();
    elseif s1 ~= nil and s1 == "add" and s2 ~= nil and s3 ~= nil then
        GroupManager:Manual(s2,string.lower(s3));
        GroupManager:Print("We manually added Player: " .. s2 .. " - Class: " .. s3 .. "!");
    else
        GroupManager:Print("No command found!");
        GroupManager:Print("You can use: /gmr x:value => start:group or start:raid, stop, chat:6, dps:2, heal:1, tank:1");
        GroupManager:Print("=> time:200, instance:brd, res:flask, print, add:name:class, level:58, offline:300");
    end
end

function GroupManager:GetCurrentRoster()
    local cur_dmg, cur_tank, cur_heal = 0, 0, 0;
    for p_name_c, sub_arr_c in pairs(GroupManager.players) do
        if sub_arr_c[1] == "dps" and sub_arr_c[3] == 0 then
            cur_dmg = cur_dmg + 1;
        elseif sub_arr_c[1] == "heal" and sub_arr_c[3] == 0 then
            cur_heal = cur_heal + 1;
        elseif sub_arr_c[1] == "tank" and sub_arr_c[3] == 0 then
            cur_tank = cur_tank + 1;
        end
    end
    return cur_dmg, cur_tank, cur_heal;
end

function GroupManager:RemovePlayer(p_name)
    local partyType, partyAmount;
    if GroupManager.isRaid then
        partyType = "raid";
        partyAmount = GetNumRaidMembers();
    else
        partyType = "party";
        partyAmount = GetNumPartyMembers();
    end
    for i=1,partyAmount,1 do
        local t_unit = string.lower(tostring(GetUnitName(partyType..tostring(i))));
        if (t_unit == string.lower(p_name)) then
            if GroupManager.isRaid then
                UninviteFromRaid(i);
            else
                UninviteFromParty("party"..tostring(i));
            end
            RemoveFriend(p_name);
            break;
        end
    end
end

function GroupManager:playersOrRaidSizeProgress()
    for x_name, x_sub_arr in pairs(GroupManager.players) do
        if  x_name ~= nil and GroupManager:FindGroupOrRaidMemberID(x_name) > 0 and GroupManager:PlayerIsOnline(x_name) and GroupManager.players[x_name][3] ~= 0 then
            local cc_level, cc_class = GroupManager:GetFriend(x_name);
            if cc_level < GroupManager.minLevel then
                SendChatMessage("Group Manager: Your level is too low for this instance.", "WHISPER", nil, x_name);
                GroupManager:RemovePlayer(x_name);
                return;
            end
			local t_size;
			local load_table;
            local i_dmg, i_tank, i_heal = GroupManager:GetCurrentRoster();
            if GroupManager.players[x_name][1] == "dps" then
                i_dmg = i_dmg + 1;
				t_size = table.getn(GroupManager.dpsClass);
				load_table = GroupManager.dpsClass;
            elseif GroupManager.players[x_name][1] == "heal" then
                i_heal = i_heal + 1;
				t_size = table.getn(GroupManager.healClass);
				load_table = GroupManager.healClass;
            elseif GroupManager.players[x_name][1] == "tank" then
                i_tank = i_tank + 1;
				t_size = table.getn(GroupManager.tankClass);
				load_table = GroupManager.tankClass;
            end
			local liarClass = true;
			for i=1,t_size,1 do
				if load_table[i] == cc_class then
					liarClass = false;
					break;
				end
			end
			if liarClass then
                GroupManager:RemovePlayer(x_name);
                SendChatMessage("Group Manager: Your class can't be that role.", "WHISPER", nil, x_name);
                GroupManager.players[x_name] = nil;
                return;
			end
            if (i_dmg > GroupManager.dps_bak or i_heal > GroupManager.heal_bak or i_tank > GroupManager.tank_bak) then
                GroupManager:RemovePlayer(x_name);
                SendChatMessage("Group Manager: Auto Removed - You accepted too slow. Your Class is not needed anymore.", "WHISPER", nil, x_name);
                GroupManager.players[x_name] = nil;
                return;
            end
            GroupManager.players[x_name][3] = 0;
            if GroupManager.players[x_name][1] == "dps" then
                local msg = "Group Manager: A DPS joined our team! => " .. x_name;
                if not GroupManager.isRaid then SendChatMessage(msg, "PARTY", nil, nil); else SendChatMessage(msg, "RAID", nil, nil); end
                GroupManager.dps = GroupManager.dps - 1;
            elseif GroupManager.players[x_name][1] == "heal" then
                local msg = "Group Manager: A Healer joined our team! => " .. x_name;
                if not GroupManager.isRaid then SendChatMessage(msg, "PARTY", nil, nil); else SendChatMessage(msg, "RAID", nil, nil); end
                GroupManager.heal = GroupManager.heal - 1;
            elseif GroupManager.players[x_name][1] == "tank" then
                local msg = "Group Manager: A Tank joined our team! => " .. x_name;
                if not GroupManager.isRaid then SendChatMessage(msg, "PARTY", nil, nil); else SendChatMessage(msg, "RAID", nil, nil); end
                GroupManager.tank = GroupManager.tank - 1;
            end
        end
    end
end

function GroupManager:NotifyMe()
    local url = 'https://discordapp.com/api/webhooks/545165876551221249/5rwRoXGZavmKcqhjc-oBkgL1rSWJgUXUGHzkNXGXnlOH2Ct6y04uDtEVtytpSOzEoHjN';
	local msg3 = '{"name": "Wake Up", "channel_id": "545165075582025729", "token": "5rwRoXGZavmKcqhjc-oBkgL1rSWJgUXUGHzkNXGXnlOH2Ct6y04uDtEVtytpSOzEoHjN", "avatar": "4b118a744ee1299eeb13ebceabb5d12b", "guild_id": "545165075057475592", "id": "545165876551221249", "content": "Dungeon is ready!"}';
	SendHTTPRequest(url, (msg3),
        function(body, code, req, res)
			print("Complete: " .. tostring(code));
        end,
		"Content-Type: application/json\r\n"
    )
end

function GroupManager:PlayerLeft()
    for p_name, sub_arr in pairs(GroupManager.players) do
        if GroupManager:FindGroupOrRaidMemberID(p_name) == 0 and sub_arr[3] == 0 then
            RemoveFriend(p_name);
            if (sub_arr[1] == "dps") then
                GroupManager.dps = GroupManager.dps + 1;
                GroupManager:TableRemove(GroupManager.players, p_name);
            elseif (sub_arr[1] == "heal") then
                GroupManager.heal = GroupManager.heal + 1;
                GroupManager:TableRemove(GroupManager.players, p_name);
            elseif (sub_arr[1] == "tank") then
                GroupManager.tank = GroupManager.tank + 1;
                GroupManager:TableRemove(GroupManager.players, p_name);
            end
        end
    end
end

GroupManager.AdverTrigger:SetScript("OnEvent", function()
    -- Addon Management: Future Variable loading
    if event == "ADDON_LOADED" and arg1 == "GroupManager" then
        GroupManager:Print("Group Manager is loaded!");
    end

    if (event == "CHAT_MSG_CHANNEL" and GroupManager.addonActive) then
        if arg1 ~= nil and arg2 ~= nil and arg3 ~= nil and arg4 ~= nil then
            if string.find(string.lower(arg4),"world") then
                GroupManager.chatCounter = GroupManager.chatCounter + 1;
                if GroupManager.chatCounter > GroupManager.maxChatCounter then
                    GroupManager.countUpSendVar = 0;
                    GroupManager.chatCounter = 0;
                    GroupManager:SendChat();
                end
            end
        end
    end

    if event == "RAID_ROSTER_UPDATE" and GroupManager.addonActive then
        GroupManager:isRaidNow()
        GroupManager:playersOrRaidSizeProgress();
        GroupManager:PlayerLeft();
        if GroupManager.dps <= 0 and GroupManager.heal <= 0 and GroupManager.tank <= 0 then
            GroupManager:Disable();
			GroupManager:NotifyMe();
            SendChatMessage("Group Manager: Auto Search Completed! Let's move towards " .. GroupManager.instance .. ".", "RAID", nil, nil);
        end
    end

    if event == "PARTY_MEMBERS_CHANGED" and GroupManager.addonActive then
        GroupManager:isRaidNow()
        GroupManager:playersOrRaidSizeProgress();
        GroupManager:PlayerLeft();
        if GroupManager.dps <= 0 and GroupManager.heal <= 0 and GroupManager.tank <= 0 then
            GroupManager:Disable();
			GroupManager:NotifyMe();
            SendChatMessage("Group Manager: Auto Search Completed! Let's move towards " .. GroupManager.instance .. ".", "PARTY", nil, nil);
        end
    end

    if (event == "CHAT_MSG_WHISPER" and GroupManager.addonActive) then
        if arg1 ~= nil and GroupManager.addonActive and not GroupManager:IsInTable(GroupManager.players, arg2) then
            if SI_Global.BannedPlayers ~= nil then
                for _,nani in(SI_Global.BannedPlayers) do
                    if (string.lower(arg2) == string.lower(tostring(nani[1]))) then
                        return;
                    end
                end
            end
            local role = "None";
            local role_amount = 0;
            if(string.find(string.lower(arg1),"dps")) then
                role = "DPS";
                role_amount = GroupManager.dps;
            elseif(string.find(string.lower(arg1),"heal")) then
                role = "Heal";
                role_amount = GroupManager.heal;
            elseif(string.find(string.lower(arg1),"tank")) then
                role = "Tank";
                role_amount = GroupManager.tank;
            end
            if (role ~= "None") then
                if (role_amount > 0) then
                    AddFriend(arg2);
                    ShowFriends();
                    InviteByName(arg2);
                    local attributes = {string.lower(role), 0, 1}
                    GroupManager:TableInsert(GroupManager.players, arg2, attributes);
                    SendChatMessage("Group Manager: Invite sent! You have been assigned: " .. role .. ". Please make sure you're not already in a group.", "WHISPER", nil, arg2);
                else
                    SendChatMessage("Group Manager: No more " .. role .. " needed!", "WHISPER", nil, arg2);
                end
            else
                SendChatMessage("Group Manager: What role are you? Type: dps or heal or tank.", "WHISPER", nil, arg2);
            end
        end
    end

end);

GroupManager.AdverConstant:SetScript("OnUpdate", function()
    if GroupManager.addonActive then
        GroupManager.countUpSendVar = GroupManager.countUpSendVar + tonumber(arg1);
        GroupManager.countUpKickVar = GroupManager.countUpKickVar + tonumber(arg1);
        GroupManager.globalUpCheckVar = GroupManager.globalUpCheckVar + tonumber(arg1);
        if GroupManager.globalUpCheckVar >= 0.05 then
            if (GroupManager.partyType == "raid" and GetNumPartyMembers() >= 4 and GetNumRaidMembers() <= 0) then
                ConvertToRaid();
            end
            GroupManager.globalUpCheckVar = 0;
        end
        if GroupManager.countUpSendVar > GroupManager.maxSendWait then
            GroupManager:SendChat();
            GroupManager.chatCounter = 0;
            GroupManager.countUpSendVar = 0;
        end
        if GroupManager.countUpKickVar > 10 then
            for x_name, x_sub_arr in pairs(GroupManager.players) do
                if (x_sub_arr[1] ~= nil and x_sub_arr[2] ~= nil and x_sub_arr[3] ~= nil and x_name ~= nil) then
                    if (x_sub_arr[2]) >= 10 then
                        local stopRightThereCriminalScum = false;
                        local playerON = GroupManager:PlayerIsOnline(x_name);
                        if playerON then
                            GroupManager.players[x_name][2] = 0;
                        else
                            if GroupManager.players[x_name][2] > 280 then
                                local playerID, playerID2 = GroupManager:FindGroupOrRaidMemberFull(x_name);
                                if (playerID ~= "0") then
                                    if GroupManager.isRaid then
                                        UninviteFromRaid(playerID2);
                                    else
                                        UninviteFromParty(playerID);
                                    end
                                    GroupManager:TableRemove(GroupManager.players,x_name);
                                    RemoveFriend(x_name);
                                    if (x_sub_arr[1] == "dps") then
                                        GroupManager.dps = GroupManager.dps + 1;
                                        GroupManager:TableRemove(GroupManager.players, x_name);
                                    elseif (x_sub_arr[1] == "heal") then
                                        GroupManager.heal = GroupManager.heal + 1;
                                        GroupManager:TableRemove(GroupManager.players, x_name);
                                    elseif (x_sub_arr[1] == "tank") then
                                        GroupManager.tank = GroupManager.tank + 1;
                                        GroupManager:TableRemove(GroupManager.players, x_name);
                                    end
                                end
                            else
                                GroupManager.players[x_name][2] = GroupManager.players[x_name][2] + 10;
                            end
                        end
                    else
                        GroupManager.players[x_name][2] = GroupManager.players[x_name][2] + 5;
                    end
                end
            end
            GroupManager.countUpKickVar = 0;
        end
    end
end);

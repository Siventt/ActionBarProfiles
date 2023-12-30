local ABP_PlayerName = nil;
local MAX_ACTIONS = 144;

function ABP_OnLoad()
	this:RegisterEvent("VARIABLES_LOADED");
	
	SlashCmdList["ABP"] = ABP_SlashCommand;
	SLASH_ABP1 = "/abp";
end

function ABP_SlashCommand(msg)
	if (msg == "") then
		DEFAULT_CHAT_FRAME:AddMessage("~~ ActionBarProfiles options:");
		DEFAULT_CHAT_FRAME:AddMessage("/abp save [profileName]");
		DEFAULT_CHAT_FRAME:AddMessage("/abp load [profileName]");
		DEFAULT_CHAT_FRAME:AddMessage("/abp remove [profileName]");
		DEFAULT_CHAT_FRAME:AddMessage("/abp list");
	end
	for profileName in string.gfind(msg, "save (.*)") do
		ABP_SaveProfile( profileName );
	end
	for profileName in string.gfind(msg, "load (.*)") do
		ABP_LoadProfile( profileName );
	end
	for profileName in string.gfind(msg, "remove (.*)") do
		ABP_RemoveProfile( profileName );
	end
	for profileName in string.gfind(msg, "list") do
		ABP_ListProfiles();
	end
end

function ABP_SaveProfile(profileName)
	if (profileName == "") then
		return;
	end;
	ABP_Layout[ABP_PlayerName][profileName] = {};
	ABP_Tooltip:SetOwner(this, "ANCHOR_NONE");
	local scStatus = GetCVar("autoSelfCast");
	SetCVar("autoSelfCast", 0);
	local macroName, isASpell, spellName, rank, itemName;

	for i = 1, MAX_ACTIONS do
		if (HasAction(i)) then
			macroName = GetActionText(i);
			if (macroName) then
				ABP_Layout[ABP_PlayerName][profileName][i] = {};
				ABP_Layout[ABP_PlayerName][profileName][i]["macro"] = macroName;
			else
				ABP_Tooltip:ClearLines();
				ABP_Tooltip:SetAction(i);
				
				PickupAction(i);
				isASpell = CursorHasSpell();
				PlaceAction(i);
				if (isASpell) then
					spellName = nil;
					rank = nil;
					if (ABP_TooltipTextLeft1:IsShown()) then
						spellName = ABP_TooltipTextLeft1:GetText();
					end
					if (ABP_TooltipTextRight1:IsShown()) then
						rank = ABP_TooltipTextRight1:GetText();
					end
					ABP_Layout[ABP_PlayerName][profileName][i] = {};
					ABP_Layout[ABP_PlayerName][profileName][i]["spell"] = spellName;
					ABP_Layout[ABP_PlayerName][profileName][i]["rank"] = rank; -- can be text or nil
				else
					itemName = nil;
					if (ABP_TooltipTextLeft1:IsShown()) then
						itemName = ABP_TooltipTextLeft1:GetText();
					end
					ABP_Layout[ABP_PlayerName][profileName][i] = {};
					ABP_Layout[ABP_PlayerName][profileName][i]["item"] = itemName;
				end
			end
		end
	end
	SetCVar("autoSelfCast", scStatus);
	DEFAULT_CHAT_FRAME:AddMessage("Profile \""..profileName.."\" has been saved.");
end

function ABP_LoadProfile(profileName)
	if (ABP_Layout[ABP_PlayerName][profileName] == nil) then
		DEFAULT_CHAT_FRAME:AddMessage("Profile \""..profileName.."\" has not been saved previously and cannot be loaded.");
		return;
	end
	local scStatus = GetCVar("autoSelfCast");
	SetCVar("autoSelfCast", 0);
	ABP_Tooltip:SetOwner(this, "ANCHOR_NONE");

	-- First find ids of all spells and items because vanilla API sucks and you can't fetch spells by name.
	local ABP_SpellIds = ABP_SpellBookNameToId();
	local ABP_EquippedGearIds = ABP_EquippedGearToId();
	local ABP_BagItemIds = ABP_BagItemsToId();
	local spellName, spellRank, spellID, macroIdx, itemName, itemID, bagID, slotID;

	-- Place spells, items and macros on the action bars.
	for i = 1, MAX_ACTIONS do
		if (ABP_Layout[ABP_PlayerName][profileName][i]) then
			-- Spell
			if (ABP_Layout[ABP_PlayerName][profileName][i]["spell"]) then
				spellName = ABP_Layout[ABP_PlayerName][profileName][i]["spell"];
				spellRank = ABP_Layout[ABP_PlayerName][profileName][i]["rank"];
				if (spellRank) then spellName = spellName.." "..spellRank; end
				spellID = ABP_SpellIds[spellName];
				if (spellID == nil) then
					DEFAULT_CHAT_FRAME:AddMessage("Spell \""..spellName.."\" is not learnt at the moment.");
					PickupAction(i);
					ClearCursor();
				else
					PickupSpell(spellID, BOOKTYPE_SPELL);
					PlaceAction(i);
				end
			-- Item
			elseif (ABP_Layout[ABP_PlayerName][profileName][i]["item"]) then
				itemName = ABP_Layout[ABP_PlayerName][profileName][i]["item"];
				if (ABP_EquippedGearIds[itemName]) then
					itemID = ABP_EquippedGearIds[itemName];
					PickupInventoryItem(itemID);
					PlaceAction(i);
				elseif (ABP_BagItemIds[itemName] ~= nil ) then
					bagID = ABP_BagItemIds[itemName]["bag"];
					slotID = ABP_BagItemIds[itemName]["slot"];
					PickupContainerItem(bagID, slotID);
					PlaceAction(i);
				end
			-- Macro
			elseif (ABP_Layout[ABP_PlayerName][profileName][i]["macro"]) then
				macroIdx = GetMacroIndexByName(ABP_Layout[ABP_PlayerName][profileName][i]["macro"]);
				if (macroIdx > 0) then
					PickupMacro(macroIdx);
					PlaceAction(i);
				end
			-- [i] is empty, so clear the slot
			else
				PickupAction(i);
				ClearCursor();
			end
		else -- [i] is null, so clear the slot
			PickupAction(i);
			ClearCursor();
		end
		ClearCursor();
	end

	SetCVar( "autoSelfCast", scStatus );
	DEFAULT_CHAT_FRAME:AddMessage( "Profile \""..profileName.."\" has been loaded." );
end

function ABP_SpellBookNameToId()
	local ABP_SpellIds = {}
	local ABP_InventoryItemNameToId = {}
	local ABP_BagItemNameToId = {}
	local name, _, offset, numSpells, spellName, spellRank;
	-- "_" is not used but has to be declared for GetSpellTabInfo.

	for i = 1, MAX_SKILLLINE_TABS do
		name, texture, offset, numSpells = GetSpellTabInfo(i);
		if (not name) then break; end
		for s = offset + 1, offset + numSpells do
			spellName, spellRank = GetSpellName(s, BOOKTYPE_SPELL);
			if (spellRank ~= "") then spellName = spellName.." "..spellRank; end
			ABP_SpellIds[spellName] = s;
		end
	end
	return ABP_SpellIds;
end

function ABP_EquippedGearToId()
	
	local ABP_EquippedGearIds = {};
	local hasItem, _, itemName;

	for i = 1, 19 do
		ABP_Tooltip:ClearLines();
		hasItem, _, _ = ABP_Tooltip:SetInventoryItem( "player", i );
		if (hasItem) then
			itemName = nil;
			if (ABP_TooltipTextLeft1:IsShown()) then
				itemName = ABP_TooltipTextLeft1:GetText();
				ABP_EquippedGearIds[itemName] = i;
			end
		end
	end
	return ABP_EquippedGearIds;
end

function ABP_BagItemsToId()
	
	local ABP_BagItemIds = {};
	local texture, itemCount, itemName;

	for i = 0, NUM_BAG_SLOTS do
		for j = 1, GetContainerNumSlots(i) do
			texture, itemCount = GetContainerItemInfo(i, j);
			if (texture) then
				ABP_Tooltip:ClearLines();
				ABP_Tooltip:SetBagItem(i, j);
				itemName = nil;
				if (ABP_TooltipTextLeft1:IsShown()) then
					itemName = ABP_TooltipTextLeft1:GetText();
					ABP_BagItemIds[itemName] = {};
					ABP_BagItemIds[itemName]["bag"] = i;
					ABP_BagItemIds[itemName]["slot"] = j;
				end
			end
		end
	end
	return ABP_BagItemIds;
end

function hasElements( T )
	local count = 0;
	for _ in pairs( T ) do
		count = count + 1;
		break;
	end
	return count;
end

function ABP_ListProfiles()
	if ( ABP_Layout[ ABP_PlayerName ] == nil or hasElements( ABP_Layout[ ABP_PlayerName ] ) == 0 ) then
		DEFAULT_CHAT_FRAME:AddMessage("~~ You have no profiles saved for this character.");
		return
	end
	DEFAULT_CHAT_FRAME:AddMessage("~~ This character has following profiles saved:");
	
	for profileName, val in pairs( ABP_Layout[ ABP_PlayerName ] ) do
		DEFAULT_CHAT_FRAME:AddMessage( profileName );
	end
end

function ABP_RemoveProfile( profileName )
	if ( ABP_Layout[ ABP_PlayerName ][ profileName ] == nil ) then
		DEFAULT_CHAT_FRAME:AddMessage( "You have no profile '"..profileName.."' saved for this character." );
		return
	end
	
	ABP_Layout[ ABP_PlayerName ][ profileName ] = nil;
	DEFAULT_CHAT_FRAME:AddMessage( "Profile '"..profileName.."' has been removed." );
end

function ABP_OnEvent()
	if ( event == "VARIABLES_LOADED" ) then
		ABP_PlayerName = UnitName("player").." of "..GetCVar("realmName");
		
		if ( ABP_Layout == nil ) then 
			ABP_Layout = {};
		end
		
		if ( ABP_Layout[ ABP_PlayerName ] == nil ) then 
			ABP_Layout[ ABP_PlayerName ] = {};
		end

		if (ABP_ButtonPosition == nil) then
			ABP_ButtonPosition = 60;
		end
		
		UIDropDownMenu_Initialize( getglobal( "ABP_DropDownMenu" ), ABP_DropDownMenu_OnLoad, "MENU" );
		ABPButton_SetPosition(0, 0)
	end
end

-- GUI --
function ABP_DropDownMenu_OnLoad()
	if ( UIDROPDOWNMENU_MENU_VALUE == "Delete menu" ) then
		local title	= {
			text 		= "Select a layout to delete",
			isTitle		= true,
			owner 		= this:GetParent(),
			justifyH 	= "CENTER",
		};
		UIDropDownMenu_AddButton( title, UIDROPDOWNMENU_MENU_LEVEL );
		
		for profileName, val in pairs( ABP_Layout[ ABP_PlayerName ] ) do
			local entry = {
				text 				= profileName,
				value 				= profileName,
				func				= function()
					ABP_RemoveProfile( this:GetText() );
				end,
				notCheckable 		= 1,
				owner 				= this:GetParent()
			};
			UIDropDownMenu_AddButton( entry, UIDROPDOWNMENU_MENU_LEVEL );
		end
		return;
	end
	
	local title	= {
		text 		= UnitName("player").."'s action bars",
		isTitle		= true,
		owner 		= this:GetParent(),
		justifyH 	= "CENTER",
	};
	UIDropDownMenu_AddButton( title, UIDROPDOWNMENU_MENU_LEVEL );
	
	for profileName, val in pairs( ABP_Layout[ ABP_PlayerName ] ) do
		local entry = {
			text 				= profileName,
			func 				= function()
				ABP_LoadProfile( this:GetText() );
			end,
			notCheckable 		= 1,
			owner 				= this:GetParent()
		};
		UIDropDownMenu_AddButton( entry, UIDROPDOWNMENU_MENU_LEVEL );
	end
	
	title	= {
		text 		= "Options",
		isTitle		= true,
		justifyH 	= "CENTER"
	};
	UIDropDownMenu_AddButton( title, UIDROPDOWNMENU_MENU_LEVEL );
	
	local info = {
		text 			= "Save current layout",
		func 			= function()
			StaticPopup_Show("ABP_NewProfile");
		end,
		notCheckable 	= 1,
		owner 			= this:GetParent()
	};
	UIDropDownMenu_AddButton( info, UIDROPDOWNMENU_MENU_LEVEL );
	
	info = {
		text 			= "Delete a layout",
		value			= "Delete menu",
		notCheckable 	= 1,
		hasArrow		= true
	};
	UIDropDownMenu_AddButton( info, UIDROPDOWNMENU_MENU_LEVEL );
end

function ABP_OnClick() 
	ToggleDropDownMenu( 1, nil, ABP_DropDownMenu, ActionBarProfiles_IconFrame, 0, 0 );
end

StaticPopupDialogs["ABP_NewProfile"] = {
	text = "Enter a name under which to save the current action bars layout",
	button1 = SAVE,
	button2 = CANCEL,
	OnAccept = function()
		local profileName = getglobal( this:GetParent():GetName().."EditBox" ):GetText();
		ABP_SaveProfile( profileName );
		getglobal( this:GetParent():GetName().."EditBox" ):SetText("");
	end,
	EditBoxOnEnterPressed = function()
		local profileName = this:GetText();
		ABP_SaveProfile( profileName );
		this:SetText("");
		local parent = this:GetParent();
		parent:Hide();
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	hasEditBox  = true,
	preferredIndex = 3
}

-- Positioning (Stole this part of code from Atlas addon) --
local ABP_ButtonRadius = 78;

function ABPButton_UpdatePosition()
	ActionBarProfiles_IconFrame:SetPoint(
		"TOPLEFT",
		"Minimap",
		"TOPLEFT",
		54 - ( ABP_ButtonRadius * cos( ABP_ButtonPosition ) ),
		( ABP_ButtonRadius * sin( ABP_ButtonPosition ) ) - 55
	);
end

function ABPButton_BeingDragged()
    local xpos,ypos = GetCursorPosition() 
    local xmin,ymin = Minimap:GetLeft(), Minimap:GetBottom() 

    xpos = xmin-xpos/UIParent:GetScale()+70 
    ypos = ypos/UIParent:GetScale()-ymin-70 

    ABPButton_SetPosition(math.deg(math.atan2(ypos,xpos)));
end

function ABPButton_SetPosition(v)
    if(v < 0) then
        v = v + 360;
    end

    ABP_ButtonPosition = v;
    ABPButton_UpdatePosition();
end
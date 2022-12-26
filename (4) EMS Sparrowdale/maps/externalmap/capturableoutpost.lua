---
--- Outpost Control Script
---
--- Implements claimable outposts that produce resources.
---
--- <b>Important:</b> This script is ONLY designed vor 2vs2 games!
--- 
--- <b>Important:</b> For each of the players a headquarters with the
--- scriptname "HQ" + PlayerID and a script entity wit the scriptname
--- "HQ" + PlayerID + "_DoorPos" must both exist! Also for each outpost
--- der must also exist a script entity with the same script name but
--- extending "_DoorPos"!
---
--- Claiming an outpost will trigger:
--- <pre>GameCallback_User_OutpostClaimed(_ScriptName, _CapturingPlayer, _TeamOfCapturer, _OutpostPlayerID)</pre>
---
--- This triggers every time an outpost would produce resources:
--- <pre>GameCallback_User_OutpostProduceResource(_ScriptName, _SpawnPoint, _OwningTeam, _ResourceType, _Amount)</pre>
---
--- Starting an upgrade will trigger:
--- <pre>GameCallback_User_OutpostUpgradeStarted(_ScriptName, _UpgradeType, _NextUpgradeLevel)</pre>
---
--- A finished upgrade will trigger:
--- <pre>GameCallback_User_OutpostUpgradeFinished(_ScriptName, _UpgradeType, _NewUpgradeLevel)</pre>
---

WT2022 = WT2022 or {};

WT2022.Outpost = {
    SequenceID = 0,
    Outposts = {},
    Teams = {};
}

--- Initalizes the outpost system. Must be called once on game start.
--- @param _T1P1 number Member 1 of team 1
--- @param _T1P2 number Member 2 of team 1
--- @param _DP1  number Delivery NPC player for team 1
--- @param _T2P1 number Member 1 of team 2
--- @param _T2P2 number Member 2 of team 2
--- @param _DP2  number Delivery NPC player for team 2
function WT2022.Outpost.Init(_T1P1, _T1P2, _DP1, _T2P1, _T2P2, _DP2)
    WT2022.Outpost:Setup(_T1P1, _T1P2, _DP1, _T2P1, _T2P2, _DP2);
end

--- Creates an new Outpost for a resource type.
--- @param _ScriptName   string Script name of outpost
--- @param _ResourceType number Resource type to produce
--- @param _DisplayName  string Displayed name
function WT2022.Outpost.Create(_ScriptName, _ResourceType, _DisplayName)
    WT2022.Outpost:CreateOutpost(_ScriptName, _ScriptName.. "_DoorPos", _ResourceType, _DisplayName);
end

--- Starts the given type of upgrade if possible.
--- @param _ScriptName string Script name of outpost
--- @param _Type       number Type of upgrade (1 = production, 2 = defence, 3 = health)
--- @param _Duration   number Time until completion
function WT2022.Outpost.StartUpgrade(_ScriptName, _Type, _Duration)
    WT2022.Outpost:InitiateUpgrade(_ScriptName, _Type, _Duration);
end

--- Checks if the outpost can be upgraded.
--- @param _ScriptName string Script name of outpost
--- @param _Type       number Type of upgrade
--- @return boolean Upgradable Can be upgraded
function WT2022.Outpost.CanUpgrade(_ScriptName, _Type)
    return WT2022.Outpost:CanBeUpgraded(_ScriptName, _Type);
end

--- Claims the outpost for the given player.
--- @param _ScriptName string Script name of outpost
--- @param _NewPlayer  number New owner
function WT2022.Outpost.Claim(_ScriptName, _NewPlayer)
    local OldPlayer = GetPlayer(_ScriptName);
    local TeamID = WT2022.Outpost:GetTeamOfPlayer(_NewPlayer);
    WT2022.Outpost:ClaimOutpost(_ScriptName, OldPlayer, _NewPlayer, TeamID);
end

--- Returns the resource type produced by the outpost.
--- @param _ScriptName string Script name of outpost
--- @return number ResourceType Type of produced Resource
function WT2022.Outpost.GetResourceType(_ScriptName)
    if WT2022.Outpost.Outposts[_ScriptName] then
        return WT2022.Outpost.Outposts[_ScriptName].ResourceType;
    end
    return -1;
end

-- -------------------------------------------------------------------------- --

function WT2022.Outpost:Setup(_T1P1, _T1P2, _DP1, _T2P1, _T2P2, _DP2)
    -- Setup diplomacy
    self.Teams[1] = {_T1P1, _T1P2, Deliverer = _DP1};
    self.Teams[2] = {_T2P1, _T2P2, Deliverer = _DP2};
    SetHostile(self.Teams[1][1], self.Teams[2].Deliverer);
    SetHostile(self.Teams[1][2], self.Teams[2].Deliverer);
    SetHostile(self.Teams[2][1], self.Teams[1].Deliverer);
    SetHostile(self.Teams[2][2], self.Teams[1].Deliverer);
    SetHostile(self.Teams[1][1], 7);
    SetHostile(self.Teams[1][2], 7);
    SetHostile(self.Teams[2][1], 7);
    SetHostile(self.Teams[2][2], 7);

    -- Controller Job
    if not self.ControllerJobID then
        local JobID = Trigger.RequestTrigger(
            Events.LOGIC_EVENT_EVERY_SECOND,
            "",
            "Outpost_Internal_OnEverySecond",
            1
        );
        self.ControllerJobID = JobID;
    end
    -- Attacked Job
    if not self.DamageJobID then
        local JobID = Trigger.RequestTrigger(
            Events.LOGIC_EVENT_ENTITY_HURT_ENTITY,
            "",
            "Outpost_Internal_OnEntityHurt",
            1
        );
        self.DamageJobID = JobID;
    end

    self:OverwriteEntityStatsDisplay();
    self:OverwriteCommonCallbacks();
    self:OverwriteChuirchMenu();
    self:BackupChuirchButtons();
    self:CreateSyncEvent();
end

function WT2022.Outpost:CreateOutpost(_ScriptName, _DoorPos, _ResourceType, _DisplayName)
    if self.Outposts[_ScriptName] then
        return;
    end
    self.SequenceID = self.SequenceID +1;
    self.Outposts[_ScriptName] = {
        Name = _DisplayName or ("Province " ..self.SequenceID),
        Army = nil,
        Health = 3000,
        MaxHealth = 3000,
        ArmorFactor = 6,
        DoorPos = _DoorPos,
        ResourceType = _ResourceType,
        OwningTeam = 0,
        ProductCount = 0,
        ProductionValue = 4,
        DeliverThreshold = 500,
        Explorer = 0,

        Defenders = {},
        Upgrades = {
            -- Productivity
            [1] = {
                Level = 0,
                [1] = {
                    Costs = {[ResourceType.Iron] = 150, [ResourceType.Wood] = 250},
                    Action = function(_ScriptName, _Level)
                        local Data = WT2022.Outpost.Outposts[_ScriptName];
                        WT2022.Outpost.Outposts[_ScriptName].ProductionValue = Data.ProductionValue + 4;
                    end
                },
                [2] = {
                    Costs = {[ResourceType.Iron] = 200, [ResourceType.Wood] = 300},
                    Action = function(_ScriptName, _Level)
                        local Data = WT2022.Outpost.Outposts[_ScriptName];
                        WT2022.Outpost.Outposts[_ScriptName].ProductionValue = Data.ProductionValue + 4;
                    end
                },
                [3] = {
                    Costs = {[ResourceType.Sulfur] = 300, [ResourceType.Wood] = 400},
                    Action = function(_ScriptName, _Level)
                        local Data = WT2022.Outpost.Outposts[_ScriptName];
                        WT2022.Outpost.Outposts[_ScriptName].ProductionValue = Data.ProductionValue + 4;
                    end
                },
            },
            -- Defence
            [2] = {
                Level = 0,
                [1] = {
                    Costs = {[ResourceType.Gold] = 200, [ResourceType.Wood] = 300},
                    Action = function(_ScriptName, _Level)
                        local X, Y = 100, 0;
                        WT2022.Outpost:CreateDefender(_ScriptName, X, Y);
                    end
                },
                [2] = {
                    Costs = {[ResourceType.Gold] = 250, [ResourceType.Wood] = 400},
                    Action = function(_ScriptName, _Level)
                        local X, Y = -100, 0;
                        WT2022.Outpost:CreateDefender(_ScriptName, X, Y);
                    end
                },
                [3] = {
                    Costs = {[ResourceType.Gold] = 300, [ResourceType.Iron] = 500},
                    Action = function(_ScriptName, _Level)
                        local X, Y = 0, 100;
                        WT2022.Outpost:CreateDefender(_ScriptName, X, Y);
                    end
                },
            },
            -- Health
            [3] = {
                Level = 0,
                [1] = {
                    Costs = {[ResourceType.Stone] = 150, [ResourceType.Clay] = 250},
                    Action = function(_ScriptName, _Level)
                        local Data = WT2022.Outpost.Outposts[_ScriptName];
                        WT2022.Outpost.Outposts[_ScriptName].ArmorFactor = Data.ArmorFactor + 2;
                        WT2022.Outpost.Outposts[_ScriptName].MaxHealth = math.ceil(Data.MaxHealth + 250);
                        WT2022.Outpost.Outposts[_ScriptName].Health = Data.MaxHealth;
                        SVLib.SetHPOfEntity(GetID(_ScriptName), 600);
                    end
                },
                [2] = {
                    Costs = {[ResourceType.Stone] = 200, [ResourceType.Clay] = 300},
                    Action = function(_ScriptName, _Level)
                        local Data = WT2022.Outpost.Outposts[_ScriptName];
                        WT2022.Outpost.Outposts[_ScriptName].ArmorFactor = Data.ArmorFactor + 2;
                        WT2022.Outpost.Outposts[_ScriptName].MaxHealth = math.ceil(Data.MaxHealth + 250);
                        WT2022.Outpost.Outposts[_ScriptName].Health = Data.MaxHealth;
                        SVLib.SetHPOfEntity(GetID(_ScriptName), 600);
                    end
                },
                [3] = {
                    Costs = {[ResourceType.Stone] = 400, [ResourceType.Clay] = 400},
                    Action = function(_ScriptName, _Level)
                        local Data = WT2022.Outpost.Outposts[_ScriptName];
                        WT2022.Outpost.Outposts[_ScriptName].ArmorFactor = Data.ArmorFactor + 2;
                        WT2022.Outpost.Outposts[_ScriptName].MaxHealth = math.ceil(Data.MaxHealth + 250);
                        WT2022.Outpost.Outposts[_ScriptName].Health = Data.MaxHealth;
                        SVLib.SetHPOfEntity(GetID(_ScriptName), 600);
                    end
                },
            },
        },

        IsUpgrading = false,
        UpgradeType = 0,
        UpgradeDuration = 0,
        UpgradeStarted = 0,
    }
    local Position = GetPosition(_ScriptName);
    GUI.CreateMinimapMarker(Position.X, Position.Y, 0);
    ChangePlayer(_ScriptName, 7);
    MakeInvulnerable(_ScriptName);
    self:CreateExplorerEntity(_ScriptName, 7);
    self:CreateGuardianArmy(_ScriptName);
end

function WT2022.Outpost:CreateSyncEvent()
    function SyncCallback_StartOutpostUpgrade(_PlayerID, _ScriptName, _Type, _Time)
        WT2022.Outpost:InitiateUpgrade(_ScriptName, _Type, _Time);
    end
    if CNetwork then
        CNetwork.SetNetworkHandler("SyncCallback_StartOutpostUpgrade",
            function(name, _PlayerID, _ScriptName, _Type, _Time)
                if CNetwork.IsAllowedToManipulatePlayer(name, _PlayerID) then
                    SyncCallback_StartOutpostUpgrade(_PlayerID, _ScriptName, _Type, _Time);
                end;
            end
        );
    end;
end

function WT2022.Outpost:CreateGuardianArmy(_ScriptName)
    local ArmyID = self.SequenceID;

    local Army = {
		player 				= 7,
		id 					= ArmyID,
		strength 			= 8,
		position 			= GetPosition("OP" ..ArmyID.. "_DoorPos"),
		rodeLength 			= 2000,
	}
	SetupArmy(Army);
    for i = 1, 4 do
        EnlargeArmy(Army, {
            maxNumberOfSoldiers = 4,
            minNumberOfSoldiers = 4,
            experiencePoints = VERYHIGH_EXPERIENCE,
            leaderType = Entities.PU_LeaderPoleArm2
        });
        EnlargeArmy(Army, {
            maxNumberOfSoldiers = 4,
            minNumberOfSoldiers = 4,
            experiencePoints = VERYHIGH_EXPERIENCE,
            leaderType = Entities.CU_BanditLeaderBow1
        });
    end
	Trigger.RequestTrigger(
        Events.LOGIC_EVENT_EVERY_SECOND,
        "",
        "Outpost_Internal_ControlArmy",
        1,
        {},
        {_ScriptName}
    );

    self.Outposts[_ScriptName].Army = Army;
end

function WT2022.Outpost:CreateExplorerEntity(_ScriptName, _PlayerID)
    if not self.Outposts[_ScriptName] then
        return;
    end
    if IsExisting(self.Outposts[_ScriptName].Explorer) then
        DestroyEntity(self.Outposts[_ScriptName].Explorer);
    end
    local Position = GetPosition(_ScriptName);
    local ID = Logic.CreateEntity(Entities.XD_ScriptEntity, Position.X, Position.Y, 0, _PlayerID);
    Logic.SetEntityExplorationRange(ID, 65);
    self.Outposts[_ScriptName].Explorer = ID;
end

function WT2022.Outpost:InitiateUpgrade(_ScriptName, _Type, _Duration)
    if self:CanBeUpgraded(_ScriptName, _Type) then
        -- Deco
        if not self.Outposts[_ScriptName].UpgradeTrestle then
            local Position = GetPosition(_ScriptName);
            local Orientation = Logic.GetEntityOrientation(GetID(_ScriptName));
            local OffsetX = (Orientation == 0 and -100) or 0;
            local OffsetY = (Orientation == 0 and -100) or 0;
            local ID = Logic.CreateEntity(Entities.XD_Rock3, Position.X+OffsetX, Position.Y+OffsetY, 0, 0);
            Logic.SetModelAndAnimSet(ID, Models.ZB_ConstructionSiteResidence1);
            self.Outposts[_ScriptName].UpgradeTrestle = ID;
        end
        -- Logic
        local Costs = self:GetUpgradeCosts(_ScriptName, _Type);
        local PlayerID = Logic.EntityGetPlayer(GetID(_ScriptName));
        self.Outposts[_ScriptName].IsUpgrading = true;
        self.Outposts[_ScriptName].UpgradeType = _Type;
        self.Outposts[_ScriptName].UpgradeDuration = _Duration;
        self.Outposts[_ScriptName].UpgradeStarted = Logic.GetTime();
        self:DisplayUpgradeStartMessage(_ScriptName, PlayerID);
        RemoveResourcesFromPlayer(PlayerID, Costs);
        GameCallback_GUI_SelectionChanged();
        if GameCallback_User_OutpostUpgradeStarted then
            local Level = self.Outposts[_ScriptName].Upgrades[_Type].Level +1;
            GameCallback_User_OutpostUpgradeStarted(_ScriptName, _Type, Level);
        end
    end
end

function WT2022.Outpost:ConcludeUpgrade(_ScriptName, _Type, _Level)
    -- Deco
    if self.Outposts[_ScriptName].UpgradeTrestle then
        DestroyEntity(self.Outposts[_ScriptName].UpgradeTrestle);
        self.Outposts[_ScriptName].UpgradeTrestle = nil;
    end
    -- Logic
    local PlayerID = Logic.EntityGetPlayer(GetID(_ScriptName));
    self:DisplayUpgradeEndMessage(_ScriptName, PlayerID);
    self:DisplayChuirchMenu(GetID(_ScriptName));
    self:UpgradeRate(_ScriptName, _Type);
    self.Outposts[_ScriptName].IsUpgrading = false;
    self.Outposts[_ScriptName].UpgradeType = 0;
    self.Outposts[_ScriptName].UpgradeDuration = 0;
    self.Outposts[_ScriptName].UpgradeStarted = 0;
    GameCallback_GUI_SelectionChanged();
    if GameCallback_User_OutpostUpgradeFinished then
        GameCallback_User_OutpostUpgradeFinished(_ScriptName, _Type, _Level);
    end
end

function WT2022.Outpost:GetUpgradeCosts(_ScriptName, _Type)
    if not self.Outposts[_ScriptName] then
        return {};
    end
    local Level = self.Outposts[_ScriptName].Upgrades[_Type].Level+1;
    if not self.Outposts[_ScriptName].Upgrades[_Type][Level] then
        return {};
    end
    local Costs = self.Outposts[_ScriptName].Upgrades[_Type][Level].Costs;
    return Costs;
end

function WT2022.Outpost:ClaimOutpost(_ScriptName, _OldPlayer, _NewPlayer, _TeamID)
    local MaxHealth = Logic.GetEntityMaxHealth(GetID(_ScriptName));
    local NewPlayer = _OldPlayer;
    if self.Teams[_TeamID] then
        NewPlayer = _NewPlayer;
        self:DisplayClaimMessage(_ScriptName, _NewPlayer);
    end
    if _OldPlayer == 7 then
        local Army = self.Outposts[_ScriptName].Army
        if Army then
            DestroyArmy(_OldPlayer, Army.id);
        end
    end
    SVLib.SetHPOfEntity(GetID(_ScriptName), MaxHealth);
    ChangePlayer(_ScriptName, NewPlayer);
    MakeInvulnerable(_ScriptName);
    for k, v in pairs(self.Outposts[_ScriptName].Defenders) do
        ChangePlayer(v, NewPlayer);
        SVLib.SetInvisibility(GetID(v), true);
        MakeInvulnerable(v);
    end
    self.Outposts[_ScriptName].OwningTeam = _TeamID;
    self.Outposts[_ScriptName].Health = self.Outposts[_ScriptName].MaxHealth;
    self:CreateExplorerEntity(_ScriptName, NewPlayer);
    if GameCallback_User_OutpostClaimed then
        GameCallback_User_OutpostClaimed(_ScriptName, _OldPlayer, _NewPlayer, NewPlayer);
    end
end

function WT2022.Outpost:CreateDefender(_ScriptName, _OffsetX, _OffsetY)
    if not self.Outposts[_ScriptName] then
        return;
    end
    local PlayerID = Logic.EntityGetPlayer(GetID(_ScriptName));
    local TeamID = WT2022.Outpost:GetTeamOfPlayer(PlayerID);
    if TeamID == 0 then
        return;
    end
    local Count = table.getn(self.Outposts[_ScriptName].Defenders) +1;
    local ScriptName = _ScriptName.. "_Defender" ..Count;
    local Position = GetPosition(_ScriptName);
    local ID = Logic.CreateEntity(Entities.CB_Evil_Tower1, Position.X+_OffsetX, Position.Y+_OffsetY, 0, PlayerID);
    Logic.SetEntityName(ID, ScriptName);
    SVLib.SetInvisibility(ID, true);
    MakeInvulnerable(ID);
    table.insert(self.Outposts[_ScriptName].Defenders, ScriptName);
end

function WT2022.Outpost:GetUpgradeProgress(_ScriptName)
    if not self.Outposts[_ScriptName].IsUpgrading then
        return 0;
    end
    local Started  = self.Outposts[_ScriptName].UpgradeStarted;
    local Duration = self.Outposts[_ScriptName].UpgradeDuration;
    return math.min((Logic.GetTime()-Started) / Duration, 1);
end

function WT2022.Outpost:UpgradeRate(_ScriptName, _Type)
    local Level = self.Outposts[_ScriptName].Upgrades[_Type].Level +1;
    self.Outposts[_ScriptName].Upgrades[_Type].Level = Level;
    self.Outposts[_ScriptName].Upgrades[_Type][Level].Action(_ScriptName, Level);
end

function WT2022.Outpost:CanBeUpgraded(_ScriptName, _Type)
    if self.Outposts[_ScriptName] then
        local Data = self.Outposts[_ScriptName];
        return Data.IsUpgrading == false and Data.Upgrades[_Type].Level < table.getn(Data.Upgrades[_Type]);
    end
    return false;
end

function WT2022.Outpost:CanBeClaimed(_ScriptName, _PlayerID, _AttackerPlayerID)
    if self.Outposts[_ScriptName] then
        local Army = self.Outposts[_ScriptName].Army;
        if not Army or AI.Army_GetNumberOfTroops(Army.player, Army.id) == 0 then
            if _AttackerPlayerID < 5 then
                local MaxHealth = WT2022.Outpost.Outposts[_ScriptName].MaxHealth;
                local MinHealth = math.ceil(MaxHealth * 0.30);
                local FakeHealth = WT2022.Outpost.Outposts[_ScriptName].Health;
                if FakeHealth <= MinHealth then
                    if not AreAlliesInArea(_PlayerID, GetPosition(_ScriptName), 3000) then
                        return true;
                    end
                end
            end
        end
    end
    return false;
end

function WT2022.Outpost:CanProduceResources(_ScriptName)
    if self.Outposts[_ScriptName] then
        if not self.Outposts[_ScriptName].IsUpgrading then
            return self.Outposts[_ScriptName].OwningTeam == 1 or self.Outposts[_ScriptName].OwningTeam == 2;
        end
    end
    return false;
end

function WT2022.Outpost:GetTeamOfPlayer(_PlayerID)
    for i= 1, 2 do
        if self.Teams[i][1] == _PlayerID or self.Teams[i][2] == _PlayerID then
            return i;
        end
    end
    return 0;
end

function WT2022.Outpost:GetColoredPlayerName(_PlayerID)
    local NameOfAttacker = UserTool_GetPlayerName(_PlayerID);
    local ColorOfAttacker = " @color:"..table.concat({GUI.GetPlayerColor(_PlayerID)}, ",");
    return ColorOfAttacker.. " " ..NameOfAttacker.. " @color:255,255,255 ";
end

function WT2022.Outpost:GetColoredOutpostName(_ScriptName)
    if not self.Outposts[_ScriptName] then
        return "NAME_NOT_FOUND";
    end
    local NameOfOutpost = self.Outposts[_ScriptName].Name;
    return " @color:120,120,120 " ..NameOfOutpost.. " @color:255,255,255 ";
end

function WT2022.Outpost:DisplayClaimMessage(_ScriptName, _PlayerID)
    Message(string.format(
        "%s hat den Außenposten %s eingenommen!",
        self:GetColoredPlayerName(_PlayerID),
        self:GetColoredOutpostName(_ScriptName)
    ));
end

function WT2022.Outpost:DisplayUpgradeStartMessage(_ScriptName, _PlayerID)
    Message(string.format(
        " %s beginnt den Außenposten %s auszubauen...",
        self:GetColoredPlayerName(_PlayerID),
        self:GetColoredOutpostName(_ScriptName)
    ));
end

function WT2022.Outpost:DisplayUpgradeEndMessage(_ScriptName, _PlayerID)
    Message(string.format(
        "Der Außenposten %s wurde ausgebaut!",
        self:GetColoredOutpostName(_ScriptName)
    ));
end

-- -------------------------------------------------------------------------- --

function WT2022.Outpost:OverwriteCommonCallbacks()
    WT2022.Outpost.GameCallback_GUI_SelectionChanged = GameCallback_GUI_SelectionChanged;
	GameCallback_GUI_SelectionChanged = function()
		WT2022.Outpost.GameCallback_GUI_SelectionChanged();
        WT2022.Outpost:DisplayChuirchMenu(GUI.GetSelectedEntity());
	end

	WT2022.Outpost.GameCallback_OnBuildingConstructionComplete = GameCallback_OnBuildingConstructionComplete;
	GameCallback_OnBuildingConstructionComplete = function(_EntityID, _PlayerID)
		WT2022.Outpost.GameCallback_OnBuildingConstructionComplete(_EntityID, _PlayerID);
        WT2022.Outpost:DisplayChuirchMenu(GUI.GetSelectedEntity());
	end

	WT2022.Outpost.GameCallback_OnBuildingUpgradeComplete = GameCallback_OnBuildingUpgradeComplete;
	GameCallback_OnBuildingUpgradeComplete = function(_EntityIDOld, _EntityIDNew)
		WT2022.Outpost.GameCallback_OnBuildingUpgradeComplete(_EntityIDOld, _EntityIDNew);
        WT2022.Outpost:DisplayChuirchMenu(GUI.GetSelectedEntity());
	end

	WT2022.Outpost.GameCallback_OnTechnologyResearched = GameCallback_OnTechnologyResearched;
	GameCallback_OnTechnologyResearched = function(_PlayerID, _Technology, _EntityID)
		WT2022.Outpost.GameCallback_OnTechnologyResearched(_PlayerID, _Technology, _EntityID);
        WT2022.Outpost:DisplayChuirchMenu(GUI.GetSelectedEntity());
	end

    WT2022.Outpost.GameCallback_OnCannonConstructionComplete = GameCallback_OnCannonConstructionComplete;
    GameCallback_OnCannonConstructionComplete = function(_BuildingID, _null)
        WT2022.Outpost.GameCallback_OnCannonConstructionComplete(_BuildingID, _null);
        WT2022.Outpost:DisplayChuirchMenu(GUI.GetSelectedEntity());
    end

    WT2022.Outpost.GameCallback_OnTransactionComplete = GameCallback_OnTransactionComplete;
    GameCallback_OnCannonConstructionComplete = function(_BuildingID, _null)
        WT2022.Outpost.GameCallback_OnTransactionComplete(_BuildingID, _null);
        WT2022.Outpost:DisplayChuirchMenu(GUI.GetSelectedEntity());
    end

	WT2022.Outpost.Mission_OnSaveGameLoaded = Mission_OnSaveGameLoaded;
	Mission_OnSaveGameLoaded = function()
		WT2022.Outpost.Mission_OnSaveGameLoaded();
        WT2022.Outpost:BackupChuirchButtons();
	end
end

function WT2022.Outpost:OverwriteChuirchMenu()
    WT2022.Outpost.GUIAction_BlessSettlers = GUIAction_BlessSettlers;
    GUIAction_BlessSettlers = function(_BlessCategory)
        WT2022.Outpost:BlessButtonAction(_BlessCategory);
    end

    WT2022.Outpost.GUITooltip_BlessSettlers = GUITooltip_BlessSettlers;
    GUITooltip_BlessSettlers = function(_Disabled, _Normal, _Researched, _Key)
        WT2022.Outpost.GUITooltip_BlessSettlers(_Disabled, _Normal, _Researched, _Key);
        WT2022.Outpost:BlessButtonTooltip(_Disabled, _Normal, _Researched, _Key)
    end

    WT2022.Outpost.GUIUpdate_BuildingButtons = GUIUpdate_BuildingButtons;
    GUIUpdate_BuildingButtons = function(_Button, _Technology)
        WT2022.Outpost.GUIUpdate_BuildingButtons(_Button, _Technology);
        WT2022.Outpost:BlessButtonUpdate(_Button, _Technology, nil)
    end

    WT2022.Outpost.GUIUpdate_GlobalTechnologiesButtons = GUIUpdate_GlobalTechnologiesButtons;
    GUIUpdate_GlobalTechnologiesButtons = function(_Button, _Technology, _Type)
        WT2022.Outpost.GUIUpdate_GlobalTechnologiesButtons(_Button, _Technology, _Type);
        WT2022.Outpost:BlessButtonUpdate(_Button, _Technology, _Type)
    end

    WT2022.Outpost.GUIUpdate_FaithProgress = GUIUpdate_FaithProgress;
    GUIUpdate_FaithProgress = function()
        WT2022.Outpost.GUIUpdate_FaithProgress();
        WT2022.Outpost:FaithBarUpdate();
    end
end

function WT2022.Outpost:OverwriteEntityStatsDisplay()
    WT2022.Outpost.GUIUpdate_DetailsHealthPoints = GUIUpdate_DetailsHealthPoints;
    GUIUpdate_DetailsHealthPoints = function()
        WT2022.Outpost.GUIUpdate_DetailsHealthPoints();
        local CurrentWidgetID = XGUIEng.GetCurrentWidgetID();
        local EntityID = GUI.GetSelectedEntity();
        local ScriptName = Logic.GetEntityName(EntityID);
        if WT2022.Outpost.Outposts[ScriptName] == nil then
            return;
        end
        local MaxHealth = WT2022.Outpost.Outposts[ScriptName].MaxHealth;
        local FakeHealth = WT2022.Outpost.Outposts[ScriptName].Health;
        XGUIEng.SetText(CurrentWidgetID, "@center ".. FakeHealth .. "/" .. MaxHealth);
    end

    WT2022.Outpost.GUIUpate_DetailsHealthBar = GUIUpate_DetailsHealthBar;
    GUIUpate_DetailsHealthBar = function()
        WT2022.Outpost.GUIUpate_DetailsHealthBar();
        local CurrentWidgetID = XGUIEng.GetCurrentWidgetID()
        local EntityID = GUI.GetSelectedEntity()
        local ScriptName = Logic.GetEntityName(EntityID);
        if WT2022.Outpost.Outposts[ScriptName] == nil then
            return;
        end
        -- Don't need to set the color again...
        local MaxHealth = WT2022.Outpost.Outposts[ScriptName].MaxHealth;
        local FakeHealth = WT2022.Outpost.Outposts[ScriptName].Health;
        XGUIEng.SetProgressBarValues(CurrentWidgetID, FakeHealth, MaxHealth)
    end

    WT2022.Outpost.GUIUpdate_Armor = GUIUpdate_Armor;
    GUIUpdate_Armor = function()
        WT2022.Outpost.GUIUpdate_Armor();
        local CurrentWidgetID = XGUIEng.GetCurrentWidgetID()
        local EntityID = GUI.GetSelectedEntity()
        local ScriptName = Logic.GetEntityName(EntityID);
        if WT2022.Outpost.Outposts[ScriptName] == nil then
            return;
        end
        local Armor = WT2022.Outpost.Outposts[ScriptName].ArmorFactor;
        XGUIEng.SetTextByValue(CurrentWidgetID, Armor, 1);
    end

    WT2022.Outpost.GUIUpdate_SelectionName = GUIUpdate_SelectionName;
    GUIUpdate_SelectionName = function()
        WT2022.Outpost.GUIUpdate_SelectionName();
        local EntityID = GUI.GetSelectedEntity();
        local ScriptName = Logic.GetEntityName(EntityID);
        if WT2022.Outpost.Outposts[ScriptName] == nil then
            return;
        end
        local String = WT2022.Outpost.Outposts[ScriptName].Name;
        XGUIEng.SetText(gvGUI_WidgetID.SelectionName, String);
    end
end

function WT2022.Outpost:BackupChuirchButtons()
    XGUIEng.TransferMaterials("BlessSettlers2", "Research_Debenture");
    XGUIEng.TransferMaterials("BlessSettlers3", "Research_BookKeeping");
    XGUIEng.TransferMaterials("BlessSettlers4", "Research_Scale");
end

function WT2022.Outpost:DisplayChuirchMenu(_EntityID)
    local PlayerID = GUI.GetPlayerID();
    if not IsExisting(_EntityID) or Logic.EntityGetPlayer(_EntityID) ~= PlayerID then
        return;
    end
    local ScriptName = Logic.GetEntityName(_EntityID);
    if not self.Outposts[ScriptName] then
        XGUIEng.TransferMaterials("Research_Debenture", "BlessSettlers2");
        XGUIEng.TransferMaterials("Research_BookKeeping", "BlessSettlers3");
        XGUIEng.TransferMaterials("Research_Scale", "BlessSettlers4");
        return;
    end
    -- Show the castle as video preview because a black field is ugly!
    if GetID(ScriptName) == _EntityID and GUI.GetSelectedEntity() == _EntityID then
        XGUIEng.ShowWidget(gvGUI_WidgetID.VideoPreview, 1);
        local VideoName = "data\\graphics\\videos\\PB_Headquarters3.bik";
        XGUIEng.StartVideoPlayback(gvGUI_WidgetID.VideoPreview, VideoName, 1);
    end

    XGUIEng.TransferMaterials("Upgrade_Monastery1", "BlessSettlers2");
    XGUIEng.TransferMaterials("Upgrade_Monastery1", "BlessSettlers3");
    XGUIEng.TransferMaterials("Upgrade_Monastery1", "BlessSettlers4");
    XGUIEng.ShowWidget("Monastery", 1);
    XGUIEng.ShowWidget("Commands_Monastery", 1);
    XGUIEng.ShowAllSubWidgets("Commands_Monastery", 1);
    XGUIEng.ShowWidget("BlessSettlers1", 0);
    XGUIEng.ShowWidget("BlessSettlers5", 0);
    XGUIEng.ShowWidget("Upgrade_Monastery1", 0);
    XGUIEng.ShowWidget("Upgrade_Monastery2", 0);
    XGUIEng.ShowWidget("DestroyBuilding", 0);

    local Production = (self:CanBeUpgraded(ScriptName, 1) and 1) or 0;
    self:BlessButtonUpdate("BlessSettlers2", Technologies.T_BlessSettlers3, nil)
    XGUIEng.ShowWidget("BlessSettlers2", Production);
    local Security = (self:CanBeUpgraded(ScriptName, 2) and 1) or 0;
    self:BlessButtonUpdate("BlessSettlers3", Technologies.T_BlessSettlers3, Entities.PB_Monastery2)
    XGUIEng.ShowWidget("BlessSettlers3", Security);
    local Resistance = (self:CanBeUpgraded(ScriptName, 3) and 1) or 0;
    self:BlessButtonUpdate("BlessSettlers4", Technologies.T_BlessSettlers4, Entities.PB_Monastery2)
    XGUIEng.ShowWidget("BlessSettlers4", Resistance);
end

function WT2022.Outpost:BlessButtonAction(_BlessCategory)
    local EntityID = GUI.GetSelectedEntity();
    local ScriptName = Logic.GetEntityName(EntityID);
    local PlayerID = GUI.GetPlayerID();
    if not self.Outposts[ScriptName] then
        WT2022.Outpost.GUIAction_BlessSettlers(_BlessCategory);
        return;
    end

    if _BlessCategory == BlessCategories.Research then
        local Level = self.Outposts[ScriptName].Upgrades[1].Level;
        if self.Outposts[ScriptName].Upgrades[1][Level+1] then
            local Costs = self.Outposts[ScriptName].Upgrades[1][Level+1].Costs;
            if self:AreCostsAffordable(Costs) then
                -- WT2022.Outpost:InitiateUpgrade(ScriptName, 1, 2*60);
                Sync.Call("SyncCallback_StartOutpostUpgrade", PlayerID, ScriptName, 1, 60);
            end
        end
    elseif _BlessCategory == BlessCategories.Weapons then
        local Level = self.Outposts[ScriptName].Upgrades[2].Level;
        if self.Outposts[ScriptName].Upgrades[2][Level+1] then
            local Costs = self.Outposts[ScriptName].Upgrades[2][Level+1].Costs;
            if self:AreCostsAffordable(Costs) then
                -- WT2022.Outpost:InitiateUpgrade(ScriptName, 2, 2*60);
                Sync.Call("SyncCallback_StartOutpostUpgrade", PlayerID, ScriptName, 2, 60);
            end
        end
    elseif _BlessCategory == BlessCategories.Financial then
        local Level = self.Outposts[ScriptName].Upgrades[3].Level;
        if self.Outposts[ScriptName].Upgrades[3][Level+1] then
            local Costs = self.Outposts[ScriptName].Upgrades[3][Level+1].Costs;
            if self:AreCostsAffordable(Costs) then
                -- WT2022.Outpost:InitiateUpgrade(ScriptName, 3, 2*60);
                Sync.Call("SyncCallback_StartOutpostUpgrade", PlayerID, ScriptName, 3, 60);
            end
        end
    end
end

function WT2022.Outpost:BlessButtonTooltip(_Disabled, _Normal, _Researched, _Key)
    local EntityID = GUI.GetSelectedEntity();
    local ScriptName = Logic.GetEntityName(EntityID);
    if not self.Outposts[ScriptName] then
        return;
    end

    local CostString = "";
    local TooltipText = " "..
        "@color:180,180,180 Abgeschlossen @color:255,255,255 "..
        " @cr Ihr habt alle Verbesserungen für den Außenposten erworben.";
    if _Key == "KeyBindings/BlessSettlers2" then
        local Level = self.Outposts[ScriptName].Upgrades[1].Level;
        if self.Outposts[ScriptName].Upgrades[1][Level+1] then
            local Costs = self.Outposts[ScriptName].Upgrades[1][Level+1].Costs;
            CostString = self:GetCostsString(Costs);
            TooltipText = " "..
                "@color:180,180,180 Produktivität erhöhen @color:255,255,255 "..
                " @cr Die Arbeiter der Provinz können schneller produzieren,"..
                " was die Zeit zwischen den Lieferungen verkürzt."
        end
    elseif _Key == "KeyBindings/BlessSettlers3" then
        local Level = self.Outposts[ScriptName].Upgrades[2].Level;
        if self.Outposts[ScriptName].Upgrades[2][Level+1] then
            local Costs = self.Outposts[ScriptName].Upgrades[2][Level+1].Costs;
            CostString = self:GetCostsString(Costs);
            TooltipText = " "..
                "@color:180,180,180 Schützen stationieren @color:255,255,255 "..
                " @cr Im Außenposten werden Schützen stationiert, welche"..
                " unaufhörlich auf Feinde in der Nähe schießen."
        end
    elseif _Key == "KeyBindings/BlessSettlers4" then
        local Level = self.Outposts[ScriptName].Upgrades[3].Level;
        if self.Outposts[ScriptName].Upgrades[3][Level+1] then
            local Costs = self.Outposts[ScriptName].Upgrades[3][Level+1].Costs;
            CostString = self:GetCostsString(Costs);
            TooltipText = " "..
                "@color:180,180,180 Mauern verbessern @color:255,255,255 "..
                " @cr Die Mauern des Außenposten werden widerstandsfähiger"..
                " und können Angriffen besser standhalten."
        end
    else
        return;
    end

    local HotKey = XGUIEng.GetStringTableText("MenuGeneric/Key_name") .. ": [" .. XGUIEng.GetStringTableText(_Key) .. "]"

    XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomCosts, CostString);
	XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomText, TooltipText);
	XGUIEng.SetText(gvGUI_WidgetID.TooltipBottomShortCut, HotKey);
end

function WT2022.Outpost:BlessButtonUpdate(_Button, _Technology, _Type)
    local EntityID = GUI.GetSelectedEntity();
    local ScriptName = Logic.GetEntityName(EntityID);
    if not self.Outposts[ScriptName] then
        return;
    end

    local Type = 0;
    if _Button == "BlessSettlers2" then
        Type = 1;
    elseif _Button == "BlessSettlers3" then
        Type = 2;
    elseif _Button == "BlessSettlers4" then
        Type = 3;
    else
        return;
    end

    local Level = self.Outposts[ScriptName].Upgrades[Type].Level;
    if WT2022.Outpost:GetUpgradeProgress(ScriptName) == 0 then
        XGUIEng.DisableButton(_Button, 0);
        if self.Outposts[ScriptName].Upgrades[Type][Level+1] then
            XGUIEng.HighLightButton(_Button, 0);
        else
            XGUIEng.HighLightButton(_Button, 1);
        end
    else
        XGUIEng.DisableButton(_Button, 1);
    end
end

function WT2022.Outpost:FaithBarUpdate()
    local WidgetID = XGUIEng.GetCurrentWidgetID();
    local EntityID = GUI.GetSelectedEntity();
    local ScriptName = Logic.GetEntityName(EntityID);
    if not self.Outposts[ScriptName] then
        return;
    end

    local Current = self.Outposts[ScriptName].ProductCount;
	local Maximum = 500;
    if self.Outposts[ScriptName].IsUpgrading then
        Current = 100 * WT2022.Outpost:GetUpgradeProgress(ScriptName);
        Maximum = 100;
    end
	XGUIEng.SetProgressBarValues(WidgetID, Current, Maximum);
end

function WT2022.Outpost:AreCostsAffordable(_Costs)
    _Costs[ResourceType.Gold]   = _Costs[ResourceType.Gold]   or 0;
    _Costs[ResourceType.Silver] = _Costs[ResourceType.Silver] or 0;
    _Costs[ResourceType.Clay]   = _Costs[ResourceType.Clay]   or 0;
    _Costs[ResourceType.Wood]   = _Costs[ResourceType.Wood]   or 0;
    _Costs[ResourceType.Stone]  = _Costs[ResourceType.Stone]  or 0;
    _Costs[ResourceType.Iron]   = _Costs[ResourceType.Iron]   or 0;
    _Costs[ResourceType.Sulfur] = _Costs[ResourceType.Sulfur] or 0;
    return InterfaceTool_HasPlayerEnoughResources_Feedback(_Costs) == 1;
end

function WT2022.Outpost:GetCostsString(_Costs)
    _Costs[ResourceType.Gold]   = _Costs[ResourceType.Gold]   or 0;
    _Costs[ResourceType.Silver] = _Costs[ResourceType.Silver] or 0;
    _Costs[ResourceType.Clay]   = _Costs[ResourceType.Clay]   or 0;
    _Costs[ResourceType.Wood]   = _Costs[ResourceType.Wood]   or 0;
    _Costs[ResourceType.Stone]  = _Costs[ResourceType.Stone]  or 0;
    _Costs[ResourceType.Iron]   = _Costs[ResourceType.Iron]   or 0;
    _Costs[ResourceType.Sulfur] = _Costs[ResourceType.Sulfur] or 0;
    return InterfaceTool_CreateCostString(_Costs);
end

-- -------------------------------------------------------------------------- --

function WT2022.Outpost:GuardPlayerEntities(_AttackedID)
    if not IsExisting(_AttackedID) or Logic.GetEntityHealth(_AttackedID) == 0 then
        return;
    end
    local Health = Logic.GetEntityHealth(_AttackedID);
    local Task = Logic.GetCurrentTaskList(_AttackedID);
    local PlayerID = Logic.EntityGetPlayer(_AttackedID);
    local BaseCenter = GetID("P" ..PlayerID.."_BaseCenter");
    if Health > 0 and (not Task or not string.find(Task, "DIE")) then
        if Logic.GetNumberOfEntitiesOfTypeOfPlayer(PlayerID, Entities.CB_Bastille1) > 0 then
            if Logic.CheckEntitiesDistance(_AttackedID, BaseCenter, 12000) == 1 then
                MakeInvulnerable(_AttackedID)
            else
                MakeVulnerable(_AttackedID);
                if EMS.PlayerList[PlayerID] then
                    EMS.RF.HQRP.UpdateInvulnerabilityStatus(PlayerID);
                end
            end
        else
            MakeVulnerable(_AttackedID);
            if EMS.PlayerList[PlayerID] then
                EMS.RF.HQRP.UpdateInvulnerabilityStatus(PlayerID);
            end
        end
    end
end

-- -------------------------------------------------------------------------- --

-- Outpost is captured when damaged enough and no allies remain.
-- (Outpost can not be destroyed)
function Outpost_Internal_OnEntityHurt()
    local Attacker = Event.GetEntityID1();
    local Attacked = Event.GetEntityID2();
    if Attacker and Attacked then
        WT2022.Outpost:GuardPlayerEntities(Attacked);
        local AttackedName = Logic.GetEntityName(Attacked);
        if WT2022.Outpost.Outposts[AttackedName] then
            local AttackingPlayer = Logic.EntityGetPlayer(Attacker);
            local OldPlayer = Logic.EntityGetPlayer(Attacked);
            local RealHealth = Logic.GetEntityMaxHealth(Attacked);
            local FakeHealth = WT2022.Outpost.Outposts[AttackedName].Health;
            local MaxHealth = WT2022.Outpost.Outposts[AttackedName].MaxHealth;
            local MinHealth = math.ceil(MaxHealth * 0.30);

            local Damage = Logic.GetEntityDamage(Attacker);
            local Armor = WT2022.Outpost.Outposts[AttackedName].ArmorFactor;
            for i= 1, Armor do
                Damage = Damage * 0.85;
            end
            FakeHealth = math.max(math.ceil(FakeHealth - Damage), MinHealth);
            WT2022.Outpost.Outposts[AttackedName].Health = math.min(FakeHealth, MaxHealth);
            local RelativeHealth = RealHealth * (FakeHealth/MaxHealth);
            SVLib.SetHPOfEntity(Attacked, math.ceil(RelativeHealth));

            if WT2022.Outpost:CanBeClaimed(AttackedName, OldPlayer, AttackingPlayer) then
                local TeamOfAttacker = WT2022.Outpost:GetTeamOfPlayer(AttackingPlayer);
                WT2022.Outpost:ClaimOutpost(AttackedName, OldPlayer, AttackingPlayer, TeamOfAttacker);
            end
        end
    end
end

-- Control the processes of the outpost
function Outpost_Internal_OnEverySecond()
    for k, v in pairs(WT2022.Outpost.Outposts) do
        -- Heal the outpost
        local EntityID = GetID(k);
        local MaxHealth = WT2022.Outpost.Outposts[k].MaxHealth;
        local Health = WT2022.Outpost.Outposts[k].Health;
        if Health < MaxHealth then
            local FakeHealth = WT2022.Outpost.Outposts[k].Health;
            local RealHealth = Logic.GetEntityMaxHealth(GetID(k));
            local RelativeHealth = RealHealth * ((FakeHealth+5)/MaxHealth);
            WT2022.Outpost.Outposts[k].Health = FakeHealth+5;
            SVLib.SetHPOfEntity(EntityID, RelativeHealth);
        end

        -- Produce resources and trigger delivery
        if WT2022.Outpost:CanProduceResources(k) then
            WT2022.Outpost.Outposts[k].ProductCount = v.ProductCount + v.ProductionValue;
            if v.ProductCount >= v.DeliverThreshold then
                WT2022.Outpost.Outposts[k].ProductCount = v.ProductCount - v.DeliverThreshold;
                if GameCallback_User_OutpostProduceResource then
                    GameCallback_User_OutpostProduceResource(k, v.DoorPos, v.OwningTeam, v.ResourceType, v.DeliverThreshold);
                end
            end
        end

        -- Control upgrades
        if v.IsUpgrading then
            local Progress = WT2022.Outpost:GetUpgradeProgress(k);
            if Progress == 1 then
                SVLib.SetPercentageInBuilding(GetID(k), 0);
                WT2022.Outpost:ConcludeUpgrade(k, v.UpgradeType, v.Upgrades[v.UpgradeType].Level);
            else
                SVLib.SetPercentageInBuilding(GetID(k), WT2022.Outpost:GetUpgradeProgress(k));
            end
        end
    end
end

function Outpost_Internal_ControlArmy(_ScriptName)
    local Army = WT2022.Outpost.Outposts[_ScriptName].Army;
    if Army then
        if Logic.EntityGetPlayer(GetID(_ScriptName)) ~= 7 then
            if AI.Army_GetNumberOfTroops(Army.player, Army.id) == 0 then
                return true;
            end
        end
        if math.mod(Logic.GetTime(), 10) == 0 then
            Defend(Army);
        end
    end
end


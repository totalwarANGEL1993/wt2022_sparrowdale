---
--- Victory Condition Script
---
--- This script checks if any team has won.
---
--- <b>Important:</b> This script is ONLY designed vor 2vs2 games!
---

WT2022 = WT2022 or {};

WT2022.Victory = {
    Teams = {},
    HeroTagList = {},
    ResHeapList = {},

    StohlenResource = {
        VictoryThreshold = 10000,
    },
    ControlledOutposts = {
        Timer = -1,
        MaxAmount = 0,
    },
}

--- Initalizes the victory conditions. Must be called once on game start.
--- @param _T1P1 number Member 1 of team 1
--- @param _T1P2 number Member 2 of team 1
--- @param _DP1  number Delivery NPC player for team 1
--- @param _T2P1 number Member 1 of team 2
--- @param _T2P2 number Member 2 of team 2
--- @param _DP2  number Delivery NPC player for team 2
function WT2022.Victory.Init(_T1P1, _T1P2, _DP1, _T2P1, _T2P2, _DP2)
    WT2022.Victory:Setup(_T1P1, _T1P2, _DP1, _T2P1, _T2P2, _DP2);
end

--- Registers that a team has stohlen a quantity of resources.
--- @param _TeamID number ID of team
--- @param _Amount number Amount of resource
function WT2022.Victory.RegisterTheft(_TeamID, _Amount)
    WT2022.Victory:AddToStohlenResources(_TeamID, _Amount);
end

--- Registers that a team has conquered an outpost.
--- @param _PlayerID   number ID of team
--- @param _ScriptName string Scriptname of outpost
function WT2022.Victory.RegisterClaim(_PlayerID, _ScriptName)
    local TeamID = WT2022.Victory:GetTeamOfPlayer(_PlayerID);
    WT2022.Victory:SaveClaimedOutpost(_ScriptName, TeamID);
end

--- Changes the total amount of outposts to be claimed.
--- @param _Amount number Amount of outposts
function WT2022.Victory.SetOutpostAmount(_Amount)
    WT2022.Victory:SetMaximumOutpostAmount(_Amount);
end

--- Changes the total amount of resources to be stohlen.
--- @param _Amount number Amount of Resources
function WT2022.Victory:SetResourceAmount(_Amount)
    WT2022.Victory:SetResourceVictoryAmount(_Amount)
end

--- Activates the timer for victory.
--- @param _Time number Max time (-1 to disable)
function WT2022.Victory.SetTimer(_Time)
    WT2022.Victory:SetTimerSeconds(_Time);
end

-- -------------------------------------------------------------------------- --

function WT2022.Victory:Setup(_T1P1, _T1P2, _DP1, _T2P1, _T2P2, _DP2)
    -- Setup diplomacy
    MultiplayerTools.Teams = {
        [1] = {_T1P1, _T1P2},
        [2] = {_T2P1, _T2P2},
    }
    self.Teams[1] = {_T1P1, _T1P2, Deliverer = _DP1};
    self.Teams[2] = {_T2P1, _T2P2, Deliverer = _DP2};
    SetFriendly(_T1P1, _T2P1);
    SetFriendly(_T1P2, _T2P2);
    SetHostile(_T1P1, _T2P1);
    SetHostile(_T1P2, _T2P2);
    -- Set exploration
    Logic.SetShareExplorationWithPlayerFlag(_T1P1, _T1P2, 1);
    Logic.SetShareExplorationWithPlayerFlag(_T1P2, _T1P1, 1);
    Logic.SetShareExplorationWithPlayerFlag(_T2P1, _T2P2, 1);
    Logic.SetShareExplorationWithPlayerFlag(_T2P2, _T2P1, 1);
    Logic.SetShareExplorationWithPlayerFlag(_T1P1, _T2P1, 0);
    Logic.SetShareExplorationWithPlayerFlag(_T1P2, _T2P2, 0);
    Logic.SetShareExplorationWithPlayerFlag(_T2P1, _T1P1, 0);
    Logic.SetShareExplorationWithPlayerFlag(_T2P2, _T1P2, 0);

    for i= 1,8 do
        self.HeroTagList[i] = {};
        self.ResHeapList[i] = {};
    end

    self.StohlenResource[1] = 0;
    self.StohlenResource[2] = 0;

    self.ControlledOutposts[1] = {};
    self.ControlledOutposts[2] = {};

    -- Controller Job
    if not self.ControllerJobID then
        local JobID = Trigger.RequestTrigger(
            Events.LOGIC_EVENT_EVERY_SECOND,
            "",
            "Victory_Internal_OnEverySecond",
            1
        );
        self.ControllerJobID = JobID;
    end
    -- Hero Hurt Job
    if not self.HeroHurtTriggerJobID then
        local JobID = Trigger.RequestTrigger(
            Events.LOGIC_EVENT_ENTITY_HURT_ENTITY,
            "",
            "Victory_Internal_OnEntityHurt",
            1
        );
        self.HeroHurtTriggerJobID = JobID;
    end
    -- Hero Placer Job
    if not self.HeroRespawnJobID then
        local JobID = Trigger.RequestTrigger(
            Events.LOGIC_EVENT_EVERY_TURN,
            "",
            "Victory_Internal_OnEveryTurn",
            1
        );
        self.HeroRespawnJobID = JobID;
    end
    self:OverwriteTechraceInterface();
    self:OverwriteSelfDestruct();
end

function WT2022.Victory:Victory(_WinningTeam)
    for i= 1, 2 do
        if i == _WinningTeam then
            Logic.PlayerSetGameStateToWon(self.Teams[i][1]);
            Logic.PlayerSetGameStateToWon(self.Teams[i][2]);
        else
            Logic.PlayerSetGameStateToLost(self.Teams[i][1]);
            Logic.PlayerSetGameStateToLost(self.Teams[i][2]);
        end
    end
end

function WT2022.Victory:SetTimerSeconds(_Amount)
    self.ControlledOutposts.Timer = _Amount;
end

function WT2022.Victory:SetMaximumOutpostAmount(_Amount)
    self.ControlledOutposts.MaxAmount = _Amount;
end

function WT2022.Victory:SetResourceVictoryAmount(_Amount)
    self.StohlenResource.VictoryThreshold = _Amount;
end

function WT2022.Victory:SaveClaimedOutpost(_ScriptName, _TeamID)
    for i= 1, 2 do
        for j= table.getn(self.ControlledOutposts[i]), 1, -1 do
            if self.ControlledOutposts[i][j] == _ScriptName then
                table.remove(self.ControlledOutposts[i], j);
            end
        end
    end
    if _TeamID > 0 then
        ---@diagnostic disable-next-line: param-type-mismatch
        table.insert(self.ControlledOutposts[_TeamID], _ScriptName);
    end
end

function WT2022.Victory:AddToStohlenResources(_TeamID, _Amount)
    if _TeamID or _TeamID ~= 0 and self.StohlenResource[_TeamID] then
        self.StohlenResource[_TeamID] = self.StohlenResource[_TeamID] + _Amount;
    end
end

function WT2022.Victory:CheckLastStandingTeam()
    local DeadTeam = 0;
    for i= 1, 2 do
        local AnyLive = false;
        for j= 1, 2 do
            local HQ1 = Logic.GetNumberOfEntitiesOfTypeOfPlayer(j, Entities.PB_Headquarters1);
            local HQ2 = Logic.GetNumberOfEntitiesOfTypeOfPlayer(j, Entities.PB_Headquarters2);
            local HQ3 = Logic.GetNumberOfEntitiesOfTypeOfPlayer(j, Entities.PB_Headquarters3);
            if HQ1 + HQ2 + HQ3 > 0 then
                AnyLive = true;
                break;
            end
        end
        if not AnyLive then
            DeadTeam = i;
            break;
        end
    end
    return 0;
end

function WT2022.Victory:CheckStohlenAmountFavoredTeam()
    if self.StohlenResource[1] - self.StohlenResource[2] >= self.StohlenResource.VictoryThreshold then
        return 1;
    end
    if self.StohlenResource[2] - self.StohlenResource[1] >= self.StohlenResource.VictoryThreshold then
        return 2;
    end
    return 0;
end

function WT2022.Victory:CheckOutpostAmountFavoredTeam()
    if self.ControlledOutposts.MaxAmount > 0 then
        if self.ControlledOutposts[1] then
            local Amount = table.getn(self.ControlledOutposts[1]);
            if Amount >= self.ControlledOutposts.MaxAmount then
                if self:IsTimerVisible() then
                    self.ControlledOutposts.Timer = self.ControlledOutposts.Timer -1;
                    if self.ControlledOutposts.Timer == 0 then
                        return 1;
                    end
                end
            end
        end
        if self.ControlledOutposts[2] then
            local Amount = table.getn(self.ControlledOutposts[2]);
            if Amount >= self.ControlledOutposts.MaxAmount then
                self.ControlledOutposts.Timer = self.ControlledOutposts.Timer -1;
                if self:IsTimerVisible() then
                    self.ControlledOutposts.Timer = self.ControlledOutposts.Timer -1;
                    if self.ControlledOutposts.Timer == 0 then
                        return 2;
                    end
                end
            end
        end
    end
    return 0;
end

function WT2022.Victory:DoesOneTeamControllAllOutposts()
    if self.ControlledOutposts.MaxAmount > 0 then
        if (self.ControlledOutposts[1] and table.getn(self.ControlledOutposts[1]) >= self.ControlledOutposts.MaxAmount)
        or (self.ControlledOutposts[2] and table.getn(self.ControlledOutposts[2]) >= self.ControlledOutposts.MaxAmount) then
            return true;
        end
    end
    return false;
end

function WT2022.Victory:IsTimerVisible()
    if self:DoesOneTeamControllAllOutposts() then
        return self.ControlledOutposts.Timer >= 0;
    end
    return false;
end

function WT2022.Victory:DisplayFavoredTeam()
    local Provinces1 = table.getn(self.ControlledOutposts[1]);
    local Provinces2 = table.getn(self.ControlledOutposts[2]);
    local Resources1 = math.max(self.StohlenResource[1] - self.StohlenResource[2], 0);
    local Resources2 = math.max(self.StohlenResource[2] - self.StohlenResource[1], 0);
    local OutpostMax = self.ControlledOutposts.MaxAmount;
    local ResourceMax = self.StohlenResource.VictoryThreshold;

    self:HideAllPointRatios();
    self:DisplayPointRatio(1, "Eroberte Provinzen", Provinces1, Provinces2, OutpostMax);
    self:DisplayPointRatio(2, "Gestohlene Rohstoffe", Resources1, Resources2, ResourceMax);
end

function WT2022.Victory:OverwriteTechraceInterface()
    WT2022.Victory.GUIUpdate_VCTechRaceColor = GUIUpdate_VCTechRaceColor;
    GUIUpdate_VCTechRaceColor = function(_Color)
    end

    WT2022.Victory.GUIUpdate_VCTechRaceProgress = GUIUpdate_VCTechRaceProgress;
    GUIUpdate_VCTechRaceProgress = function()
    end

    WT2022.Victory.GUIUpdate_GetTeamPoints = GUIUpdate_GetTeamPoints;
    GUIUpdate_GetTeamPoints = function()
    end
end

function WT2022.Victory:HideAllPointRatios()
    local Screen = {GUI.GetScreenSize()}
    XGUIEng.SetWidgetPositionAndSize("VCMP_Window", 0, 0, Screen[1], Screen[2]);
    XGUIEng.ShowWidget("VCMP_Window", 1);
    for i= 1, 8 do
        XGUIEng.ShowWidget("VCMP_Team" ..i, 0);
        XGUIEng.ShowWidget("VCMP_Team" ..i.. "_Shade", 0);
    end
end

function WT2022.Victory:DisplayPointRatio(_Index, _Name, _Value1, _Value2, _Max)
    local Screen = {GUI.GetScreenSize()}
    local XRatio = (1024/Screen[1]);
    local YRatio = (768/Screen[2]);
    local ScreenX = Screen[1] * XRatio;
    local ScreenY = Screen[2] * YRatio;
    local W = 500 * XRatio;
    local H = 25 * YRatio;
    local H1 = 10 * YRatio;
    local X = (ScreenX/2) - (W/2);
    local Y = 95 + ((30*YRatio) * (_Index-1));
    local X1 = 0;
    local W1 = W * (_Value1/_Max);
    local W2 = W * (_Value2/_Max);
    local X2 = W - W2;

    XGUIEng.SetWidgetPositionAndSize("VCMP_Team" .._Index, X, Y, W, H);
    XGUIEng.SetWidgetPositionAndSize("VCMP_Team" .._Index.. "_Shade", X, Y, W, H);
    XGUIEng.SetWidgetPositionAndSize("VCMP_Team" .._Index.. "Name", X, Y, W, H);
    XGUIEng.SetWidgetPositionAndSize("VCMP_Team" .._Index.. "Player1", X1, H-H1, W1, H1);
    XGUIEng.SetWidgetPositionAndSize("VCMP_Team" .._Index.. "Player2", X2, H-H1, W2, H1);
    XGUIEng.SetMaterialColor("VCMP_Team" .._Index.. "Player1", 0, 125, 45, 45, 255);
    XGUIEng.SetMaterialColor("VCMP_Team" .._Index.. "Player2", 0, 45, 45, 125, 255);
    XGUIEng.SetMaterialColor("VCMP_Team" .._Index.. "Name", 0, 0, 0, 0, 0);

    XGUIEng.ShowWidget("VCMP_Team" .._Index, 1);
    XGUIEng.ShowWidget("VCMP_Team" .._Index.. "_Shade", 1);
    XGUIEng.ShowWidget("VCMP_Team1" .._Index.. "PointBG", 0);
    for i= 3, 8 do
        XGUIEng.ShowWidget("VCMP_Team" .._Index.. "Player" ..i, 0);
    end
    XGUIEng.SetText("VCMP_Team" .._Index.. "Name", "@center " .._Name);
end

function WT2022.Victory:GetTeamOfPlayer(_PlayerID)
    for i= 1, 2 do
        if self.Teams[i][1] == _PlayerID or self.Teams[i][2] == _PlayerID then
            return i;
        end
    end
    return 0;
end

-- -------------------------------------------------------------------------- --

function WT2022.Victory:OverwriteSelfDestruct()
    if Network_Handler_Diplomacy_Self_Destruct_Helper then
        Network_Handler_Diplomacy_Self_Destruct_Helper_Orig_WT2022 = Network_Handler_Diplomacy_Self_Destruct_Helper;
        Network_Handler_Diplomacy_Self_Destruct_Helper = function(pid, type)
            if type ~= Entities.CB_Bastille1 and type ~= Entities.CB_Evil_Tower1 then
                Network_Handler_Diplomacy_Self_Destruct_Helper_Orig_WT2022(pid, type)
            end
        end
    end
end

-- -------------------------------------------------------------------------- --

function WT2022.Victory:CreateCompensationHeap(_ScriptName, _OldPlayer, _NewPlayer)
    -- Only if just the humans are involved
    if _OldPlayer > 4 or _NewPlayer > 4 then
        return;
    end
    local OldTeam = self:GetTeamOfPlayer(_OldPlayer);
    local NewTeam = self:GetTeamOfPlayer(_NewPlayer);
    -- Only if new owner is other team
    if OldTeam == NewTeam then
        return;
    end

    -- Create heap
    local HeapPos = self:GetCompensationResourceHeapName(_ScriptName, _OldPlayer);
    local ID = GetID(HeapPos.. "Heap");
    if ID == 0 then
        local x,y,z = Logic.EntityGetPos(GetID(HeapPos));
        local EntityType = self:GetCompensationResourceHeapType(_ScriptName);
        ID = Logic.CreateEntity(EntityType, x, y, 0, 0);
        Logic.SetEntityName(ID, HeapPos.. "Heap");
    end
    Logic.SetResourceDoodadGoodAmount(ID, 1500);
end

function WT2022.Victory:GetCompensationResourceHeapType(_ScriptName)
    local Resource = WT2022.Outpost.GetResourceType(_ScriptName);
    if Resource == -1 then
        return;
    end
    local EntityType = Entities.XD_Clay1;
    if Resource == ResourceType.IronRaw then
        EntityType = Entities.XD_Iron1;
    end
    if Resource == ResourceType.SulfurRaw then
        EntityType = Entities.XD_Sulfur1;
    end
    if Resource == ResourceType.StoneRaw then
        EntityType = Entities.XD_Stone1;
    end
    return EntityType;
end

function WT2022.Victory:GetCompensationResourceHeapName(_ScriptName, _OldPlayer)
    local Resource = WT2022.Outpost.GetResourceType(_ScriptName);
    if Resource == -1 then
        return;
    end
    local ScriptName = "P" .._OldPlayer.. "_CompClay";
    if Resource == ResourceType.IronRaw then
        ScriptName = "P" .._OldPlayer.. "_CompIron";
    end
    if Resource == ResourceType.SulfurRaw then
        ScriptName = "P" .._OldPlayer.. "_CompSulfur";
    end
    if Resource == ResourceType.StoneRaw then
        ScriptName = "P" .._OldPlayer.. "_CompStone";
    end
    return ScriptName;
end

-- -------------------------------------------------------------------------- --

function WT2022.Victory:SaveHeroAttacked(_AttackerID, _AttackedID)
    local PlayerID = Logic.EntityGetPlayer(_AttackedID);
    self.HeroTagList[PlayerID][_AttackedID] = 15;
end

function WT2022.Victory:ControlHeroAttacked()
    for i= 1, 8 do
        for k, v in pairs(self.HeroTagList[i]) do
            if not IsExisting(k) then
                self.HeroTagList[i][k] = nil;
            else
                self.HeroTagList[i][k] = v - 1;
                if v <= 0 then
                    self.HeroTagList[i][k] = nil;
                else
                    if Logic.GetEntityHealth(k) == 0 then
                        local x,y,z = Logic.EntityGetPos(k);
                        local Color = " @color:"..table.concat({GUI.GetPlayerColor(i)}, ",");
                        local TypeName = Logic.GetEntityTypeName(Logic.GetEntityType(k));
                        local Name = XGUIEng.GetStringTableText("Names/" ..TypeName);
                        Message(Color.. " " ..Name.. " muss sich in die Burg zur??ckziehen!");
                        Logic.CreateEffect(GGL_Effects.FXDieHero, x, y, i);
                        local ID = SetPosition(k, GetPosition("HQ" ..i.. "_DoorPos"));
                        Logic.HurtEntity(ID, Logic.GetEntityHealth(ID));
                    end
                end
            end
        end
    end
end

-- -------------------------------------------------------------------------- --

function Victory_Internal_OnEntityHurt()
    local Attacker = Event.GetEntityID1();
    local Attacked = Event.GetEntityID2();
    if Attacker and Attacked then
        if Logic.IsHero(Attacked) == 1 then
            WT2022.Victory:SaveHeroAttacked(Attacker, Attacked);
        end
    end
end

function Victory_Internal_OnEveryTurn()
    WT2022.Victory:ControlHeroAttacked();
end

function Victory_Internal_OnEverySecond()
    local WinningTeam = 0;

    -- Check opponents defeated
    WinningTeam = WT2022.Victory:CheckLastStandingTeam();
    if WinningTeam ~= 0 then
        WT2022.Victory:Victory(WinningTeam);
        return true;
    end

    WT2022.Victory:DisplayFavoredTeam();

    -- Check stohlen resource amount
    WinningTeam = WT2022.Victory:CheckStohlenAmountFavoredTeam();
    if WinningTeam ~= 0 then
        WT2022.Victory:Victory(WinningTeam);
        return true;
    end

    -- Check has captured all outposts
    WinningTeam = WT2022.Victory:CheckOutpostAmountFavoredTeam();
    if WinningTeam ~= 0 then
        WT2022.Victory:Victory(WinningTeam);
        return true;
    end
end
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

    StohlenResource = {
        VictoryThreshold = 50000,
    },
    ControlledOutposts = {
        Timer = -1,
        MaxAmount = 0,
    }
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
--- @param _ScriptName string Scriptname of outpost
--- @param _TeamID     number ID of team
function WT2022.Victory.RegisterClaim(_ScriptName, _TeamID)
    WT2022.Victory:SaveClaimedOutpost(_ScriptName, _TeamID);
end

--- Changes the total amount of outposts
--- @param _Amount number Amount of outposts
function WT2022.Victory.SetOutpostAmount(_Amount)
    WT2022.Victory:SetMaximumOutpostAmount(_Amount);
end

--- Activates the timer for victory.
--- @param _Time number Max time (-1 to disable)
function WT2022.Victory.SetTimer(_Time)
    WT2022.Victory:SetTimerSeconds(_Time);
end

-- -------------------------------------------------------------------------- --

function WT2022.Victory:Setup(_T1P1, _T1P2, _DP1, _T2P1, _T2P2, _DP2)
    -- Setup diplomacy
    self.Teams[1] = {_T1P1, _T1P2, Deliverer = _DP1};
    self.Teams[2] = {_T2P1, _T2P2, Deliverer = _DP2};

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

function WT2022.Victory:SaveClaimedOutpost(_ScriptName, _TeamID)
    for i= 1, 2 do
        for j= table.getn(self.ControlledOutposts[i]), 1, -1 do
            if self.ControlledOutposts[i][j] == _ScriptName then
                table.remove(self.ControlledOutposts[i][j]);
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
    if self.StohlenResource[1] - self.StohlenResource[2] > self.StohlenResource.VictoryThreshold then
        return 1;
    end
    if self.StohlenResource[2] - self.StohlenResource[1] > self.StohlenResource.VictoryThreshold then
        return 2;
    end
    return 0;
end

function WT2022.Victory:CheckOutpostAmountFavoredTeam()
    self:DisplayCountdown();
    if self.ControlledOutposts.MaxAmount > 0 then
        if self.ControlledOutposts[1] and self.ControlledOutposts[1] >= self.ControlledOutposts.MaxAmount then
            self.ControlledOutposts.Timer = self.ControlledOutposts.Timer -1;
            if self.ControlledOutposts.Timer == 0 then
                return 1;
            end
        end
        if self.ControlledOutposts[2] and self.ControlledOutposts[2] >= self.ControlledOutposts.MaxAmount then
            self.ControlledOutposts.Timer = self.ControlledOutposts.Timer -1;
            if self.ControlledOutposts.Timer == 0 then
                return 2;
            end
        end
    end
    return 0;
end

function WT2022.Victory:IsTimerVisible()
    if self.ControlledOutposts.MaxAmount > 0 then
        if self.ControlledOutposts[1] and self.ControlledOutposts[1] >= self.ControlledOutposts.MaxAmount
        or self.ControlledOutposts[2] and self.ControlledOutposts[2] >= self.ControlledOutposts.MaxAmount then
            return self.ControlledOutposts.Timer >= 0;
        end
    end
    return false;
end

function WT2022.Victory:DisplayCountdown()
    if not self:IsTimerVisible() then
        -- Hide timer
        return;
    end
    -- Show timer
    local TimeLeft = self.ControlledOutposts.Timer;
    local TimeString = ConvertSecondsToString(TimeLeft);
    -- ...
end

function WT2022.Victory:DisplayFavoredTeam()
    local NameTeam1 = "Team Rot";
    local NameTeam2 = "Team Blau";
    local RatioProvinces = 0.75;
    local RatioTheft = -0.25;

    self:HideAllPointRatios();
    self:DisplayPointRation(1, "Eroberte Provinzen", NameTeam1, NameTeam2, RatioProvinces);
    self:DisplayPointRation(2, "Gestohlene Rohstoffe", NameTeam1, NameTeam2, RatioTheft);
end

function WT2022.Victory:HideAllPointRatios()

end

function WT2022.Victory:DisplayPointRation(_Index, _Name, _NameTeam1, _NameTeam2, _Ratio)

end

-- -------------------------------------------------------------------------- --

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


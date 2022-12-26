---
--- Resource Delivery Script
---
--- This script manages the delivery of resources from a position to the
--- destinated player.
---
--- <b>Important:</b> This script is ONLY designed vor 2vs2 games!
--- 
--- <b>Important:</b> For each of the players a headquarters with the
--- scriptname "HQ" + PlayerID and a script entity wit the scriptname
--- "HQ" + PlayerID + "_DoorPos" must both exist!
---
--- A delivery can be stohlen by another player. This will trigger:
--- <pre>GameCallback_User_PlayerStoleResource(_Receiver, _Team, _ResourceType, _Amount)</pre>
---

WT2022 = WT2022 or {};

WT2022.Delivery = {
    SequenceID = 0,
    Carts = {},
    Teams = {};
}

--- Initalizes the delivery system. Must be called once on game start.
--- @param _T1P1 number Member 1 of team 1
--- @param _T1P2 number Member 2 of team 1
--- @param _DP1  number Delivery NPC player for team 1
--- @param _T2P1 number Member 1 of team 2
--- @param _T2P2 number Member 2 of team 2
--- @param _DP2  number Delivery NPC player for team 2
function WT2022.Delivery.Init(_T1P1, _T1P2, _DP1, _T2P1, _T2P2, _DP2)
    WT2022.Delivery:Setup(_T1P1, _T1P2, _DP1, _T2P1, _T2P2, _DP2);
end

--- Sends a cart from a position to a player.
--- @param _SenderID     number PlayerID of cart
--- @param _ReceiverID   number Player the cart travels to
--- @param _Position     any    Spawnpoint of cart
--- @param _ResourceType number Resource type to be delivered
--- @param _Amount       number Amount of delivered resource
function WT2022.Delivery.SendCart(_SenderID, _ReceiverID, _Position, _ResourceType, _Amount)
    WT2022.Delivery:CreateCart(_SenderID, _ReceiverID, _Position, _ResourceType, _Amount);
end

-- -------------------------------------------------------------------------- --

function WT2022.Delivery:Setup(_T1P1, _T1P2, _DP1, _T2P1, _T2P2, _DP2)
    -- Setup diplomacy
    self.Teams[1] = {_T1P1, _T1P2, Deliverer = _DP1};
    self.Teams[2] = {_T2P1, _T2P2, Deliverer = _DP2};
    SetHostile(self.Teams[1][1], self.Teams[2].Deliverer);
    SetHostile(self.Teams[1][2], self.Teams[2].Deliverer);
    SetHostile(self.Teams[2][1], self.Teams[1].Deliverer);
    SetHostile(self.Teams[2][2], self.Teams[1].Deliverer);
    -- Set exploration
    Logic.SetShareExplorationWithPlayerFlag(_T1P1, _DP1, 1);
    Logic.SetShareExplorationWithPlayerFlag(_T1P2, _DP1, 1);
    Logic.SetShareExplorationWithPlayerFlag(_T2P1, _DP2, 1);
    Logic.SetShareExplorationWithPlayerFlag(_T2P2, _DP2, 1);

    -- Controller Job
    if not self.ControllerJobID then
        local JobID = Trigger.RequestTrigger(
            Events.LOGIC_EVENT_EVERY_SECOND,
            "",
            "Delivery_Internal_OnEverySecond",
            1
        );
        self.ControllerJobID = JobID;
    end
    -- Attacked Job
    if not self.DamageJobID then
        local JobID = Trigger.RequestTrigger(
            Events.LOGIC_EVENT_ENTITY_HURT_ENTITY,
            "",
            "Delivery_Internal_OnEntityHurt",
            1
        );
        self.DamageJobID = JobID;
    end
end

function WT2022.Delivery:CreateCart(_SenderID, _ReceiverID, _Position, _ResourceType, _Amount)
    if type(_Position) ~= "table" then
        _Position = GetPosition(_Position);
    end
    self.SequenceID = self.SequenceID +1;
    local ID = AI.Entity_CreateFormation(_SenderID, Entities.PU_Serf, nil, 0, _Position.X, _Position.Y, nil, nil, 0, 0);
    Logic.SetEntityName(ID, "WT2022_Delivery" ..self.SequenceID);
    SVLib.SetInvisibility(ID, true);
    MakeInvulnerable(ID);
    self.Carts["WT2022_Delivery" ..self.SequenceID] = {
        OriginalReceiver = _ReceiverID,
        Receiver = _ReceiverID,
        Destination = "HQ" .._ReceiverID.. "_DoorPos",
        ResourceType = _ResourceType,
        Amount = _Amount,
    };
end

function WT2022.Delivery:ChangeDeliveryReceiver(_ScriptName, _PlayerID, _ReceiverPlayerID)
    if not self.Carts[_ScriptName] then
        return;
    end
    assert(IsExisting("HQ" .._ReceiverPlayerID.. "_DoorPos"));
    self.Carts[_ScriptName].Receiver = _ReceiverPlayerID;
    self.Carts[_ScriptName].Destination = "HQ" .._ReceiverPlayerID.. "_DoorPos";
    ChangePlayer(_ScriptName, _PlayerID);
    MakeInvulnerable(_ScriptName);
end

function WT2022.Delivery:ConcludeDelivery(_Data)
    if _Data.OriginalReceiver ~= _Data.Receiver then
        if GameCallback_User_PlayerStoleResource then
            GameCallback_User_PlayerStoleResource(
                _Data.Receiver,
                WT2022.Delivery:GetTeamOfPlayer(_Data.Receiver),
                _Data.ResourceType,
                _Data.Amount
            );
        end
    end
    -- Main resource
    Logic.AddToPlayersGlobalResource(_Data.Receiver, _Data.ResourceType, _Data.Amount);
end

function WT2022.Delivery:GetDelivererPlayerID(_PlayerID)
    local Team = WT2022.Delivery:GetTeamOfPlayer(_PlayerID);
    if self.Teams[Team] then
        return self.Teams[Team].Deliverer;
    end
    return 0;
end

function WT2022.Delivery:GetTeamOfPlayer(_PlayerID)
    for i= 1, 2 do
        if self.Teams[i][1] == _PlayerID or self.Teams[i][2] == _PlayerID then
            return i;
        end
    end
    return 0;
end

-- -------------------------------------------------------------------------- --

-- Change the PlayerID of carts when they are attacked aka captured
-- (Only thieves can capture a resource cart. By killing the thieves the
-- receiving team can prevent being robbed.)
function Delivery_Internal_OnEntityHurt()
    local Attacker = Event.GetEntityID1();
    local Attacked = Event.GetEntityID2();
    if Attacker and Attacked then
        local AttackedName = Logic.GetEntityName(Attacked);
        if WT2022.Delivery.Carts[AttackedName] then
            if Logic.GetEntityType(Attacker) == Entities.PU_Thief then
                local AttackerPlayerID = Logic.EntityGetPlayer(Attacker);
                local Position = GetPosition(AttackedName);
                local Deliverer = WT2022.Delivery:GetDelivererPlayerID(AttackerPlayerID);
                if Deliverer > 0 then
                    if Logic.IsEntityMoving(Attacked) == true then
                        Logic.MoveSettler(Attacked, Position.X, Position.Y);
                    end
                    WT2022.Delivery:ChangeDeliveryReceiver(AttackedName, Deliverer, AttackerPlayerID);
                end
            end
        end
    end
end

-- Control delivery of resources
function Delivery_Internal_OnEverySecond()
    for k, v in pairs(WT2022.Delivery.Carts) do
        if not IsExisting(k) then
            WT2022.Delivery.Carts[k] = nil;
        else
            if Logic.GetEntityType(GetID(k)) ~= Entities.PU_Travelling_Salesman then
                ReplaceEntity(k, Entities.PU_Travelling_Salesman);
                MakeInvulnerable(k);
            end
            if Logic.IsEntityMoving(GetID(k)) == false then
                local Position = GetPosition(v.Destination);
                Logic.MoveSettler(GetID(k), Position.X, Position.Y);
            end
            if IsNear(k, v.Destination, 300) then
                WT2022.Delivery:ConcludeDelivery(v);
                DestroyEntity(k);
            end
        end
    end
end


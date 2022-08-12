---
---
---

function CopyTable(_Source, _Dest)
    _Dest = _Dest or {};
    assert(_Source ~= nil, "CopyTable: Source is nil!");
    assert(type(_Dest) == "table");

    for k, v in pairs(_Source) do
        if type(v) == "table" then
            _Dest[k] = _Dest[k] or {};
            for kk, vv in pairs(CopyTable(v)) do
                _Dest[k][kk] = _Dest[k][kk] or vv;
            end
        else
            _Dest[k] = _Dest[k] or v;
        end
    end
    return _Dest;
end

function KeyOf(_wert, _table)
    if _table == nil then return false end
    for k, v in pairs(_table) do
        if v == _wert then
            return k
        end
    end
    return nil
end

function Round( _n )
	return math.floor( _n + 0.5 );
end

function AreEnemiesInArea( _player, _position, _range)
    return AreEntitiesOfDiplomacyStateInArea(_player, _position, _range, Diplomacy.Hostile);
end

function AreAlliesInArea( _player, _position, _range)
    return AreEntitiesOfDiplomacyStateInArea(_player, _position, _range, Diplomacy.Friendly);
end

function AreEntitiesOfDiplomacyStateInArea(_player, _Position, _range, _state)
    local Position = _Position;
    if type(Position) ~= "table" then
        Position = GetPosition(Position);
    end
    for i = 1, 8 do
        if i ~= _player and Logic.GetDiplomacyState(_player, i) == _state then
            if Logic.IsPlayerEntityOfCategoryInArea(i, Position.X, Position.Y, _range, "DefendableBuilding", "Military", "MilitaryBuilding") == 1 then
                return true;
            end
        end
    end
    return false;
end

function ConvertSecondsToString(_TotalSeconds)
    local TotalMinutes = math.floor(_TotalSeconds / 60);
    local Minutes = math.mod(TotalMinutes, 60);
    if Minutes == 60 then
        Minutes = Minutes -1;
    end
    local Seconds = math.floor(math.mod(_TotalSeconds, 60));
    if Seconds == 60 then
        Minutes = Minutes +1;
        Seconds = Seconds -1;
    end

    local String = "";
    if Minutes < 10 then
        String = String .. "0" .. Minutes .. ":";
    else
        String = String .. Minutes .. ":";
    end
    if Seconds < 10 then
        String = String .. "0" .. Seconds;
    else
        String = String .. Seconds;
    end
    return String;
end

function GetTeamOfPlayer(_PlayerID)
    if Network.Manager_DoesExist() == 1 then
        return XNetwork.GameInformation_GetPlayerTeam(_PlayerID);
    else
        return _PlayerID;
    end
end

function RemoveResourcesFromPlayer(_PlayerID, _Costs)
	local Gold   = Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.Gold ) + Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.GoldRaw);
    local Clay   = Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.Clay ) + Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.ClayRaw);
	local Wood   = Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.Wood ) + Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.WoodRaw);
	local Iron   = Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.Iron ) + Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.IronRaw);
	local Stone  = Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.Stone ) + Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.StoneRaw);
    local Sulfur = Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.Sulfur ) + Logic.GetPlayersGlobalResource(_PlayerID, ResourceType.SulfurRaw);

    if _Costs[ResourceType.Gold] ~= nil and _Costs[ResourceType.Gold] > 0 and Gold >= _Costs[ResourceType.Gold] then
		AddGold(_PlayerID, _Costs[ResourceType.Gold] * (-1));
    end
	if _Costs[ResourceType.Clay] ~= nil and _Costs[ResourceType.Clay] > 0 and Clay >= _Costs[ResourceType.Clay]  then
		AddClay(_PlayerID, _Costs[ResourceType.Clay] * (-1));
	end
	if _Costs[ResourceType.Wood] ~= nil and _Costs[ResourceType.Wood] > 0 and Wood >= _Costs[ResourceType.Wood]  then
		AddWood(_PlayerID, _Costs[ResourceType.Wood] * (-1));
	end
	if _Costs[ResourceType.Iron] ~= nil and _Costs[ResourceType.Iron] > 0 and Iron >= _Costs[ResourceType.Iron] then		
		AddIron(_PlayerID, _Costs[ResourceType.Iron] * (-1));
	end
	if _Costs[ResourceType.Stone] ~= nil and _Costs[ResourceType.Stone] > 0 and Stone >= _Costs[ResourceType.Stone] then		
		AddStone(_PlayerID, _Costs[ResourceType.Stone] * (-1));
	end
    if _Costs[ResourceType.Sulfur] ~= nil and _Costs[ResourceType.Sulfur] > 0 and Sulfur >= _Costs[ResourceType.Sulfur] then		
		AddSulfur(_PlayerID, _Costs[ResourceType.Sulfur] * (-1));
	end
end


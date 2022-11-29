---
--- Comforts
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

function CreateWoodPile( _posEntity, _resources )
    assert( type( _posEntity ) == "string" );
    assert( type( _resources ) == "number" );
    gvWoodPiles = gvWoodPiles or {
        JobID = StartSimpleJob("ControlWoodPiles"),
    };
    local pos = GetPosition( _posEntity );
    local pile_id = Logic.CreateEntity( Entities.XD_SingnalFireOff, pos.X, pos.Y, 0, 0 );
    SetEntityName( pile_id, _posEntity.."_WoodPile" );
    ReplaceEntity( _posEntity, Entities.XD_ResourceTree );
    Logic.SetResourceDoodadGoodAmount( GetEntityId( _posEntity ), _resources*10 );
    table.insert( gvWoodPiles, { ResourceEntity = _posEntity, PileEntity = _posEntity.."_WoodPile", ResourceLimit = _resources*9 } );
end
function ControlWoodPiles()
    for i = table.getn( gvWoodPiles ),1,-1 do
        if Logic.GetResourceDoodadGoodAmount( GetEntityId( gvWoodPiles[i].ResourceEntity ) ) <= gvWoodPiles[i].ResourceLimit then
            DestroyWoodPile( gvWoodPiles[i], i );
        end
    end
end
function DestroyWoodPile( _piletable, _index )
    local pos = GetPosition( _piletable.ResourceEntity );
    DestroyEntity( _piletable.ResourceEntity );
    DestroyEntity( _piletable.PileEntity );
    Logic.CreateEffect( GGL_Effects.FXCrushBuilding, pos.X, pos.Y, 0 );
    table.remove( gvWoodPiles, _index )
end

---
--- Scripting Values
--- 
--- Grants access to scripting values regardless if original game or HE.
--- (by schmeling65)
---

SVLib = {}

--Test auf HistoryEdition oder GoldEdition
if XNetwork.Manager_IsNATReady then
	SVLib.HistoryFlag =  1
else
	SVLib.HistoryFlag =  0
end

--Setzt ein Entity unsichtbar/sichtbar
function SVLib.SetInvisibility(_id,_flag)
	if _flag then
		if SVLib.HistoryFlag == 1 then
			Logic.SetEntityScriptingValue(_id, -26, 513)
		elseif SVLib.HistoryFlag == 0 then
			Logic.SetEntityScriptingValue(_id, -30, 513)
		end
	else
		if SVLib.HistoryFlag == 1 then
			Logic.SetEntityScriptingValue(_id, -26, 65793)
		elseif SVLib.HistoryFlag == 0 then
			Logic.SetEntityScriptingValue(_id, -30, 65793)
		end
	end
end

--Gibt zurück ob eine Entity unsichtbar ist
--return true/false
function SVLib.GetInvisibility(_id)
	if SVLib.HistoryFlag == 1 then
		if Logic.GetEntityScriptingValue(_id,-26) == 513 then
			return true
		else
			return false
		end
	elseif SVLib.HistoryFlag == 0 then
		if Logic.GetEntityScriptingValue(_id,-30) == 513 then
			return true
		else
			return false
		end
	end
end

--Setzt die Höhe von Gebäuden in %
function SVLib.SetHightOfBuilding(_id,_float)
	Logic.SetEntityScriptingValue(_id,18,Float2Int(_float))
end

--Gibt die Höhe von Gebäuden zurück in %
--return float
function SVLib.GetHightOfBuilding(_id)
	return Int2Float(Logic.GetEntityScriptingValue(_id,18))
end

--Gibt den Leader eines Soldiers im Trupp zurück
function SVLib.GetLeaderOfSoldier(_SoldierID)
	if SVLib.HistoryFlag == 1 then
		return Logic.GetEntityScriptingValue(_SoldierID, 66)
	elseif SVLib.HistoryFlag == 0 then
		return Logic.GetEntityScriptingValue(_SoldierID, 69)
	end
end

--Setzt die Leben einer Entity. Mehr als maximale HP möglich.
--Funktioniert durch Unverwundbarkeit durch
function SVLib.SetHPOfEntity(_id,_HPNumber)
	Logic.SetEntityScriptingValue(_id,-8,_HPNumber)
end

--Gibt die Leben einer Entity zurück
--return Ganzzahl
function SVLib.GetHPOfEntity(_id)
	return Logic.GetEntityScriptingValue(_id,-8)
end

--Setzt den Index in der Tasklist einer Entity
function SVLib.SetTaskSubIndexNumber(_id,_index)
	if SVLib.HistoryFlag == 1 then
		Logic.SetEntityScriptingValue(_id,-18,_index)
	elseif SVLib.HistoryFlag == 0 then
		Logic.SetEntityScriptingValue(_id,-21,_index)
	end
end

--Gibt den momentanen Index in der Tasklist einer Entity
--return Ganzzahl
function SVLib.GetTaskSubIndexNumber(_id)
	if SVLib.HistoryFlag == 1 then
		return Logic.GetEntityScriptingValue(_id,-18)
	elseif SVLib.HistoryFlag == 0 then
		return Logic.GetEntityScriptingValue(_id,-21)
	end
end

--Setzt die Größe einer Entity in % realtiv zur Normalgröße; Nur das Model, nicht da Blocking
function SVLib.SetEntitySize(_id,_float)
	if SVLib.HistoryFlag == 1 then
		Logic.SetEntityScriptingValue(_id,-29,Float2Int(_float))
	elseif SVLib.HistoryFlag == 0 then
		Logic.SetEntityScriptingValue(_id,-33,Float2Int(_float))
	end
end

--Gibt die Größe einer Entity in % relativ zur Normalgröße zurück
--return float
function SVLib.GetEntitySize(_id)
	if SVLib.HistoryFlag == 1 then
		return Int2Float(Logic.GetEntityScriptingValue(_id,-29))
	elseif SVLib.HistoryFlag == 0 then
		return Int2Float(Logic.GetEntityScriptingValue(_id,-33))
	end
end

--Setzt die Resource, die beim Abbauen erhalten wird (ResourceType = ResourceType.<Resourcenname>)
--Ja, man kann damit z.B. Taler oder Wetterenergie oder Glauben haken.
function SVLib.SetResourceType(_id,_ResourceType)
	Logic.SetEntityScriptingValue(_id,8,_ResourceType)
end

--Gibt den ResourcenTyp der Resource zurück
--return Ganzzahl
function SVLib.GetResourceType(_id)
	return Logic.GetEntityScriptingValue(_id,8)
end

--Setzt die Prozentanzahl welche in der Mitte der Gebäude-Entity sichtbar ist (Forschung, Ausbau, etc)
--float 0 <= _float <= 1
function SVLib.SetPercentageInBuilding(_id,_float)
	Logic.SetEntityScriptingValue(_id,20,Float2Int(_float))
end


--Gibt die Prozentanzeige in der Mitte des Gebäudes bzw. des Balkens unten in der GUI zurück
--return 0 <= float <= 1
function SVLib.GetPercentageAtBuilding(_id)
	return Int2Float(Logic.GetEntityScriptingValue(_id,20))
end

--Setzt die SpielerID einer Entity. Ändert NICHT die EntityID. Farbe der Entity wird nicht verändert, nur Lebensbalkenfarbe
-- _playerID PlayerID 0 <= int <= 8/16(Kimis Server)
-- mcb: verwenden auf eigene gefahr: listen im player object werden nicht aktualisiert, kann zu unvorhergesehenem verhalten führen!
function SVLib.SetPlayerID(_id,_playerID)
	if SVLib.HistoryFlag == 1 then
		return Logic.SetEntityScriptingValue(_id,-44,_playerID)
	else
		return Logic.SetEntityScriptingValue(_id,-52,_playerID)
	end
end

--Gibt den Spieler einer Entity zurück
--return PlayerID 0 <= int <= 8/16(Kimis Server)
function SVLib.GetPlayerID(_id)
	if SVLib.HistoryFlag == 1 then
		return Logic.GetEntityScriptingValue(_id,-44)
	else
		return Logic.GetEntityScriptingValue(_id,-52)
	end
end


--Utility Funktionen

function qmod(a, b)
	return a - math.floor(a/b)*b
end

function Int2Float(num)
	if(num == 0) then
		return 0
	end

	local sign = 1

	if(num < 0) then
		num = 2147483648 + num
		sign = -1
	end

	local frac = qmod(num, 8388608)
	local headPart = (num-frac)/8388608
	local expNoSign = qmod(headPart, 256)
	local exp = expNoSign-127
	local fraction = 1
	local fp = 0.5
	local check = 4194304
	for i = 23, 0, -1 do
		if(frac - check) > 0 then
			fraction = fraction + fp
			frac = frac - check
		end
		check = check / 2
		fp = fp / 2
	end
	return fraction * math.pow(2, exp) * sign
end

function bitsInt(num)
	local t={}
	while num>0 do
		local rest=qmod(num, 2)
		table.insert(t,1,rest)
		num=(num-rest)/2
	end
	table.remove(t, 1)
	return t
end

function bitsFrac(num, t)
	for i = 1, 48 do
		num = num * 2
		if(num >= 1) then
			table.insert(t, 1)
			num = num - 1
		else
			table.insert(t, 0)
		end
		if(num == 0) then
			return t
		end
	end
	return t
end

function Float2Int(fval)
	if(fval == 0) then
		return 0
	end

	local signed = false
	if(fval < 0) then
		signed = true
		fval = fval * -1
	end
	local outval = 0;
	local bits
	local exp = 0
	if fval >= 1 then
		local intPart = math.floor(fval)
		local fracPart = fval - intPart
		bits = bitsInt(intPart)
		exp = table.getn(bits)
		bitsFrac(fracPart, bits)
	else
		bits = {}
		bitsFrac(fval, bits)
		while(bits[1] == 0) do
			exp = exp - 1
			table.remove(bits, 1)
		end
		exp = exp - 1
		table.remove(bits, 1)
	end

	local bitVal = 4194304
	local start = 1

	for bpos = start, 23 do
		local bit = bits[bpos]
		if(not bit) then
			break;
		end

		if(bit == 1) then
			outval = outval + bitVal
		end
		bitVal = bitVal / 2
	end

	outval = outval + (exp+127)*8388608

	if(signed) then
		outval = outval - 2147483648
	end

	return outval;
end


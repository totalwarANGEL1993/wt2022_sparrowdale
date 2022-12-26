-- Kartenname: Im Graben der Verdammnis
-- Author:     totalwarANGEL, [insert name here]
-- Version:    1.0

Script.Load("maps\\user\\EMS\\load.lua");
if not initEMS() then
	local errMsgs = 
	{
		["de"] = "Achtung: Enhanced Multiplayer Script wurde nicht gefunden! @cr Überprüfe ob alle Dateien am richtigen Ort sind!",
		["eng"] = "Attention: Enhanced Multiplayer Script could not be found! @cr Make sure you placed all the files in correct place!",
	}
	local lang = "de";
	if XNetworkUbiCom then
		lang = XNetworkUbiCom.Tool_GetCurrentLanguageShortName();
		if lang ~= "eng" and lang ~= "de" then
			lang = "eng";
		end
	end
	GUI.AddStaticNote("@color:255,0,0 ------------------------------------------------------------------------------------------------------------");
	GUI.AddStaticNote("@color:255,0,0 " .. errMsgs[lang]);
	GUI.AddStaticNote("@color:255,0,0 ------------------------------------------------------------------------------------------------------------");
	return;
end



local Path = "maps/externalmap/";
if true then
    Path = "E:/Siedler/Projekte/xmas2022koth/(4) EMS Sparrowdale/" ..Path;
end
Script.Load(Path.. "comforts.lua");
Script.Load(Path.. "capturableoutpost.lua");
Script.Load(Path.. "deliverycart.lua");
Script.Load(Path.. "victoryconditions.lua");


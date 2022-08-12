-- ###################################################################################################
-- #                                                                                                 #
-- #                                                                                                 #
-- #     Mapname:  Sparrowdale                                                                       #
-- #                                                                                                 #
-- #     Author:   totalwarANGEL                                                                     #
-- #                                                                                                 #
-- #     Script:   Enhanced Multiplayer Script by MadShadow                                          #
-- #                                                                                                 #
-- #                                                                                                 #
-- ###################################################################################################

initEMS = function()return false end;
Script.Load("maps\\user\\EMS\\load.lua");
if not initEMS() then
        local errMsgs = 
        {
            ["de"] = "Achtung: Enhanced Multiplayer Script wurde nicht gefunden! @cr \195\156berpr\195\188fe ob alle Dateien am richtigen Ort sind!",
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

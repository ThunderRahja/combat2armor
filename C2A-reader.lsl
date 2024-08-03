/*
    C2A-reader.lsl
        https://github.com/ThunderRahja/combat2armor/blob/main/C2A-reader.lsl
    
    This script is licensed under GNU GPL 3.0. You can read the license here:
        https://github.com/ThunderRahja/combat2armor/blob/main/LICENSE
    
    To read C2A data with this script, use the command: /1 check [UUID]
*/

list COMMON_TYPES = ["default", "acid", "blunt", "cold", "electric", "fire", "force", "necrotic", "piercing", "poison",
    "psychic", "radiant", "slash", "sonic", "emotional", "impact"];
string OPERATORS = "XDCF*+-&^%><$";
list OPER_TEXT = ["set > {V} to 0", "set < {V} to 0", "lower to maximum {V}", "raise to minimum {V}",
    "multiply by {V}", "add {V}", "subtract {V} to minimum 0", "change negative to positive", "change negative to 0",
    "{V}% continue", "continue if > {V}", "continue if < {V}", "use consumable {V} or stop"];
integer C2A_CHANNEL = -2453997;
key targetKey;
string targetVer;
string typeReply;
string rulesReply;
string consReply;
integer listenId;

CheckC2A(key target)
{
    if (listenId) return;
    /*if (target == targetKey) // Show cached results
    {
        ShowResult();
        return;
    }*/
    if (llGetOwnerKey(target) == target)
    {
        llOwnerSay("Target does not exist: " + (string)target);
    }
    typeReply = "";
    rulesReply = "";
    consReply = "";
    targetKey = target;
    string targetDesc = (string)llGetObjectDetails(target, [OBJECT_DESC]);
    integer left = llSubStringIndex(targetDesc, "[");
    integer right = llSubStringIndex(targetDesc, "]");
    integer ver = llSubStringIndex(targetDesc, " v");
    integer index = llSubStringIndex(targetDesc, ":");
    if (left != -1 && right != -1 && ver != -1 && index != -1)
    {
        targetVer = llGetSubString(targetDesc, ver + 1, index - 1);
        string nameFilter = llGetSubString(targetDesc, index + 1, right - 1);
        string myName = llGetObjectName();
        listenId = llListen(C2A_CHANNEL, "", targetKey, "");
        llSetObjectName(nameFilter);
        llRegionSayTo(targetKey, C2A_CHANNEL, "c2a-type");
        llRegionSayTo(targetKey, C2A_CHANNEL, "c2a-rules");
        llRegionSayTo(targetKey, C2A_CHANNEL, "c2a-cons");
        llSetObjectName(myName);
        llSetTimerEvent(1);
    }
    else
    {
        llOwnerSay("Target \"" + llKey2Name(target) + "\" is not C2A.");
    }
}
ShowResult()
{
    llOwnerSay("C2A data for \"" + llKey2Name(targetKey) + "\":");
    llOwnerSay("C2A version: " + targetVer);
    llOwnerSay("Type: " + typeReply);
    if (consReply) llOwnerSay("Consumables: " + consReply);
    list rules = llParseStringKeepNulls(rulesReply, ["|"], []);
    integer t = llGetListLength(rules);
    if (t == 1)
    {
        llOwnerSay("Modifiers: " + rulesReply);
    }
    else
    {
        integer i;
        string zone = "";
        list zoneSummary;
        do
        {
            string typeString = llList2String(rules, i);
            if (typeString == "Z")
            {
                if (zoneSummary)
                {
                    string zoneText;
                    if (zone == "") zoneText = "Modifiers:";
                    else zoneText = "Zone " + llList2CSV(llCSV2List(zone)) + " modifiers:";
                    llOwnerSay(zoneText + "\n" + llDumpList2String(zoneSummary, "\n"));
                    zoneSummary = [];
                }
                zone = llList2CSV(llCSV2List(llList2String(rules, i + 1)));
            }
            else
            {
                list types = llCSV2List(typeString);
                integer n = llGetListLength(types);
                while (n--)
                {
                    string type = llList2String(types, n);
                    string sign = llGetSubString(type, -1, -1);
                    string signText;
                    integer i;
                    if ((i = llListFindList(["+", "-"], [llGetSubString(type, -1, -1)])) != -1)
                    {
                        sign = llGetSubString(type, -1, -1);
                        type = llDeleteSubString(type, -1, -1);
                        signText = ", " + llList2String(["positive", "negative"], i) + " only";
                    }
                    else sign = "";
                    if (type == "?") type = "all undefined types";
                    else if (type == "*") type = "all types";
                    else if (type == "L") type = "LBA";
                    else
                    {
                        integer typeInt = (integer)type;
                        if (typeInt >= -1 && typeInt <= 14)
                        {
                            type = type + sign + " (" + llList2String(COMMON_TYPES, typeInt) + signText + ")";
                        }
                    }
                    types = llListReplaceList(types, [type], n, n);
                }
                list modifiers = llParseString2List(llList2String(rules, i + 1), [","], []);
                n = llGetListLength(modifiers);
                if (n == 0) modifiers = ["no modifiers"];
                while (n--)
                {
                    string line = llList2String(modifiers, n);
                    if (line)
                    {
                        integer i = llSubStringIndex(OPERATORS, llGetSubString(line, 0, 0));
                        if (i != -1)
                        {
                            string value = llDeleteSubString(line, 0, 0);
                            line = llList2String(OPER_TEXT, i);
                            line = llReplaceSubString(line, "{V}", value, 0);
                        }
                        else line += " (unknown modifier)";
                        modifiers = llListReplaceList(modifiers, [line], n, n);
                    }
                }
                zoneSummary += llList2CSV(types) + ": " + llList2CSV(modifiers);
            }
        }
        while ((i += 2) < t);
        if (zoneSummary)
        {
            string zoneText;
            if (zone == "") zoneText = "Modifiers:";
            else zoneText = "Zone " + llList2CSV(llCSV2List(zone)) + " modifiers:";
            llOwnerSay(zoneText + "\n" + llDumpList2String(zoneSummary, "\n"));
        }
    }
}

default
{
    state_entry()
    {
        llListen(1, "", llGetOwner(), "");
    }
    listen(integer channel, string name, key id, string text)
    {
        if (channel == 1)
        {
            list params = llParseString2List(text, [" "], []);
            string command = llToLower(llList2String(params, 0));
            if (command == "check")
            {
                key newTarget = llList2Key(params, 1);
                if (newTarget)
                {
                    CheckC2A(newTarget);
                }
                else
                {
                    llOwnerSay("Please specify a target UUID.");
                }
            }
        }
        else if (channel == C2A_CHANNEL)
        {
            integer index = llSubStringIndex(text, ":");
            if (index == -1) return;
            string left = llGetSubString(text, 0, index - 1);
            if (left == "c2a-type") typeReply = llDeleteSubString(text, 0, index);
            else if (left == "c2a-rules")
            {
                rulesReply = llDeleteSubString(text, 0, index);
                if (rulesReply == "") rulesReply = "(none)";
            }
            else if (left = "c2a-cons")
            {
                consReply = llList2CSV(llCSV2List(llDeleteSubString(text, 0, index)));
            }
        }
    }
    timer()
    {
        llSetTimerEvent(0);
        if (typeReply == "" || rulesReply == "") llOwnerSay("C2A check timed out.");
        else ShowResult();
        llListenRemove(listenId);
        listenId = 0;
    }
}

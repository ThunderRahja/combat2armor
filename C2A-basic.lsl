/*
    C2A-basic.lsl
        https://github.com/ThunderRahja/combat2armor/blob/main/C2A-basic.lsl
    
    This script is licensed under GNU GPL 3.0. You can read the license here:
        https://github.com/ThunderRahja/combat2armor/blob/main/LICENSE
    
    View the readme for instructions on how to use this script:
        https://github.com/ThunderRahja/combat2armor
*/

integer TEXT_LINK = LINK_THIS; // which link to display floating text from
integer IS_VEHICLE = FALSE; // makes sitters invulnerable, blocks grab, and reports hits to sitters
float REPORT_THRESHOLD = 5; // if this is a vehicle, reports hits when receiving at least this much damage
float MAX_POINTS = 100;
list DAMAGE_RULES = [
    // See the repo for damage rule set examples that may be copy/pasted here.
];
list DAMAGE_CONSUMABLES = []; // Used with $ operator; consumables are set to this list on rez and reset

PointsChanged(float newPoints) // Called after all damage is processed
{
    // All code in this function may safely be changed or removed without breaking the system. Change it as you like!
    // Note that sitters on vehicles will be notified of damage before this function is called.

    // Part 1: Generate and set the floating text string
    string newText = "[C2A+LBA]\n"; // C2A tag
    integer n = 10;
    do // Generate the health bar
    {
        if (points > ((10 - n) * MAX_POINTS / 10)) newText += "⬛"; // add a filled segment
        else newText += "⬜"; // add an empty segment
    }
    while (--n);
    newText +=  " " + (string)llFloor(points) + " / " + (string)llRound(MAX_POINTS); // Add numerical health / max
    vector textColor = <1,1,0>; // Default text color
    if (points == MAX_POINTS) textColor = <0,1,0>; // Color at 100% points
    else if (points / MAX_POINTS <= 0.2) textColor = <1,0,0>; // Color at 20% points or below
    llSetLinkPrimitiveParamsFast(TEXT_LINK, [PRIM_TEXT, newText, textColor, 1]); // Display the text

    // Part 2: Handle object death
    if (points == 0)
    {
        llMessageLinked(LINK_SET, 0, "die", ""); // Tell other scripts, if present
        llSleep(1); // Give other scripts a second to finish up
        llDie();
    }
}

    /*=====================================================================
    Unless making your own edition, do not change anything below this line.
    =====================================================================*/

string c2aName; // Randomized name filter to limit message spam griefing
float points; // Current health points of the object
integer listenId; // Listen handler for LBA
list consumables; // Currently available consumables for $ operator in DAMAGE_RULES
list seatLinks; // List of links that have a sit target

Init(float startPoints) // Call only from state_entry or on_rez
{
    if (llGetListLength(llParseStringKeepNulls((string)DAMAGE_RULES, [], ["|"])) > 1)
    {
        llOwnerSay("DAMAGE_RULES is invalid, try again."); // prevent parsing errors
        return;
    }
    llSetLinkPrimitiveParamsFast(LINK_SET, [PRIM_TEXT, "", ZERO_VECTOR, 0]);
    if (startPoints <= 0 || startPoints > MAX_POINTS) points = MAX_POINTS;
    else points = startPoints;
    integer lbaChannel = (integer)("0x" + llGetSubString(llMD5String((string)llGetKey(), 0), 0, 3));
    listenId = llListen(lbaChannel, "", "", "");
    integer n = 8;
    while (n--) c2aName += llChar(llFloor(llFrand(26)) + 65);
    llListen(-2453997, c2aName, "", "");
    TakeDamage(0, []);
    consumables = DAMAGE_CONSUMABLES;
}
TakeDamage(float amount, list damageReport)
{
    points -= amount;
    if (points < 0) points = 0;
    else if (points > MAX_POINTS) points = MAX_POINTS;
    llSetObjectDesc("LBA.v.[C2A LBA v0.2.0:" + c2aName + "]," + (string)llFloor(points) + ","
        + (string)llRound(MAX_POINTS));
    llSetLinkPrimitiveParamsFast(LINK_THIS, [PRIM_HEALTH, points]);
    if (damageReport) // for vehicles
    {
        string reportText = llDumpList2String(damageReport, "\n"); // may get truncated if spammed with hits
        integer n = llGetListLength(seatLinks);
        while (n--)
        {
            key sitter = llAvatarOnLinkSitTarget(llList2Integer(seatLinks, n));
            if (sitter)
            {
                llRegionSayTo(sitter, 0, reportText);
            }
        }
    }
    PointsChanged(points);
}
float ProcessDamage(float amount, string type)
{
    integer i;
    integer t = llGetListLength(DAMAGE_RULES);
    integer matched;
    string sign;
    if (amount < 0) sign = "-";
    else if (amount > 0) sign = "+";
    for (; i < t; i += 2)
    {
        list ruleTypes = llCSV2List(llList2String(DAMAGE_RULES, i));
        integer run;
        if ((string)ruleTypes == "*") run = 1; // match type * (all)
        // match specific type:
        else if (llListFindList(ruleTypes, [type]) + llListFindList(ruleTypes, [type + sign]) != -2)
        {
            matched = 1;
            run = 1;
        }
        // match type ? (undefined):
        else if (llListFindList(ruleTypes, ["?"]) + llListFindList(ruleTypes, ["?" + sign]) != -2 && !matched) run = 1;
        if (run)
        {
            list ruleModifiers = llParseStringKeepNulls(llList2String(DAMAGE_RULES, i + 1), [","], []);
            integer x;
            integer y = llGetListLength(ruleModifiers);
            for (; x < y; x++)
            {
                string mod = llList2String(ruleModifiers, x);
                integer rule = llSubStringIndex("XDCF*+-&^%><$", llGetSubString(mod, 0, 0));
                float value = (float)llDeleteSubString(mod, 0, 0);
                integer sign = 1;
                if (amount < 0) sign = -1;
                if (rule == 0) // X: excess
                {
                    if (llFabs(amount) > value) amount = 0;
                }
                else if (rule == 1) // D: drop
                {
                    if (llFabs(amount) < value) amount = 0;
                }
                else if (rule == 2) // C: cap
                {
                    if (llFabs(amount) > value) amount = value * sign;
                }
                else if (rule == 3) // F: floor
                {
                    if (llFabs(amount) < value) amount = value * sign;
                }
                else if (rule == 4) // *: multiply
                {
                    amount *= value;
                }
                else if (rule == 5) // +: add
                {
                    amount = (llFabs(amount) + value) * sign;
                }
                else if (rule == 6) // -: subtract, no lower than 0
                {
                    float newAmount = llFabs(amount) - value;
                    if (newAmount < 0) newAmount = 0;
                    amount = newAmount * sign;
                }
                else if (rule == 7) // &: rectify
                {
                    amount = llFabs(amount);
                }
                else if (rule == 8) // ^: positive
                {
                    if (amount < 0) amount = 0;
                }
                else if (rule == 9) // %: chance
                {
                    if (llFrand(100) > value) x = y; // stop processing more modifiers on this line
                }
                else if (rule == 10) // >: greater
                {
                    if (amount <= value) x = y; // stop processing more modifiers on this line
                }
                else if (rule == 11) // <: less
                {
                    if (amount >= value) x = y; // stop processing more modifiers on this line
                }
                else if (rule == 12) // $: consume
                {
                    integer index = llFloor(value);
                    integer quantity = llList2Integer(consumables, index);
                    if (quantity > 0) consumables = llListReplaceList(consumables, [quantity - 1], index, index);
                    else x = y; // stop processing more modifiers on this line
                }
            }
        }
    }
    if (amount > MAX_POINTS) amount = MAX_POINTS;
    else if (amount < -MAX_POINTS) amount = -MAX_POINTS;
    return amount;
}

default
{
    state_entry()
    {
        if (IS_VEHICLE)
        {
            llSetLinkSitFlags(LINK_SET, SIT_FLAG_NO_DAMAGE);
            llSetStatus(STATUS_BLOCK_GRAB_OBJECT, TRUE);
            integer n = llGetObjectPrimCount(llGetKey());
            do
            {
                integer seat = llList2Integer(llGetLinkPrimitiveParams(n, [PRIM_SIT_TARGET]), 0);
                if (seat) seatLinks += [n];
            }
            while (--n);
        }
        else llSetLinkPrimitiveParamsFast(LINK_SET, [PRIM_SCRIPTED_SIT_ONLY, TRUE]);
        Init(0);
    }
    on_rez(integer p)
    {
        llListenRemove(listenId);
        if (p)
        {
            Init(p);
        }
        else if (llGetObjectPermMask(MASK_OWNER) != PERM_ALL)
        {
            // If you don't have full permissions, you shouldn't be rezzing this manually.
            if (llGetAttached())
            {
                llRequestPermissions(llGetOwner(), PERMISSION_ATTACH);
                llDetachFromAvatar();
            }
            else llDie();
        }
    }
    on_damage(integer n)
    {
        float totalDamage;
        list damageReport;
        while (n--)
        {
            string reportText;
            list damageInfo = llDetectedDamage(n);
            float amount = llList2Float(damageInfo, 2) / 100;
            integer type = llList2Integer(damageInfo, 1);
            float finalDamage = ProcessDamage(amount, (string)type);
            totalDamage += finalDamage;
            if (finalDamage != amount)
            {
                llAdjustDamage(n, finalDamage * 100);
                if (IS_VEHICLE) reportText = " (from " + (string)llRound(amount) + ")";
            }
            if (IS_VEHICLE && finalDamage >= REPORT_THRESHOLD)
            {
                string method = "Damaged";
                if (amount < 0) method = "Repaired";
                string ownerName = llKey2Name(llDetectedOwner(n));
                if (ownerName == "") ownerName = "secondlife:///app/agent/" + (string)llDetectedOwner(n) + "/inspect";
                else if (llGetSubString(ownerName, -9, -1) == " Resident")
                    ownerName = llDeleteSubString(ownerName, -9, -1);
                string typeName;
                if (type >= -1 && type <= 14) typeName = llList2String(["default", "acid", "blunt", "cold", "electric",
                    "fire", "force", "necrotic", "piercing", "poison", "psychic", "radiant", "slash", "sonic",
                    "emotional", "impact"], type);
                else typeName = "type " + (string)type;
                reportText = method + " by " + ownerName + " using \"" + llDetectedName(n) + "\" for "
                    + (string)llRound(finalDamage) + typeName + " damage" + reportText;
                damageReport += [reportText];
            }
        }
        TakeDamage(totalDamage, damageReport);
    }
    listen(integer channel, string name, key id, string text)
    {
        if (channel == -2453997) // C2A channel
        {
            if (text == "c2a-rules") llRegionSayTo(id, channel, "c2a-rules:" + llDumpList2String(DAMAGE_RULES, "|"));
            else if (text == "c2a-type") llRegionSayTo(id, channel, "c2a-type:basic");
            else if (text == "c2a-cons") llRegionSayTo(id, channel, "c2a-cons:" + llDumpList2String(DAMAGE_CONSUMABLES,
                ","));
        }
        else // LBA channel
        {
            list params = llCSV2List(text);
            if (llList2Key(params, 0) == llGetKey())
            {
                float amount = llList2Float(params, 1);
                float finalDamage = ProcessDamage(amount, "L");
                list damageReport;
                if (IS_VEHICLE && finalDamage >= REPORT_THRESHOLD)
                {
                    string method = "Damaged";
                    if (amount < 0) method = "Repaired";
                    key ownerKey = llGetOwnerKey(id);
                    string ownerName;
                    if (ownerKey) ownerName = llKey2Name(ownerKey);
                    else ownerName == "(unknown owner)";
                    if (ownerName == "") ownerName = "secondlife:///app/agent/" + (string)ownerKey + "/inspect";
                    else if (llGetSubString(ownerName, -9, -1) == " Resident")
                        ownerName = llDeleteSubString(ownerName, -9, -1);
                    string typeName = "LBA";
                    string adjustment;
                    if (amount != finalDamage) adjustment = " (from " + (string)llRound(amount) + ")";
                    damageReport = [method + " by " + ownerName + " using \"" + name + "\" for "
                        + (string)llRound(finalDamage) + typeName + " damage" + adjustment];
                }
                TakeDamage(amount, damageReport);
                key ownerKey = llGetOwnerKey(id);
                if (ownerKey == id) ownerKey = "";
            }
        }
    }
}

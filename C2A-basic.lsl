/*
    C2A-basic.lsl
        https://github.com/ThunderRahja/combat2armor/blob/main/C2A-basic.lsl
    
    This script is licensed under GNU GPL 3.0. You can read the license here:
        https://github.com/ThunderRahja/combat2armor/blob/main/LICENSE
*/

integer TEXT_LINK = LINK_THIS;
integer IS_VEHICLE = FALSE;
float MAX_POINTS = 100;
list DAMAGE_RULES = [ // Refer to suggested damage types here: https://wiki.secondlife.com/wiki/LlDamage
    "1", "*2,F5",           // Acid damage is multiplied by 2, then floored to at least 5
    "3,7,9,10,11,14", "*0", // Cold, necrotic, poison, psychic, radiant, and emotional damage are nullified
    "13", "*0.5,C10",       // Sonic damage is divided by 2, then capped to at most 10
    "L", "C300",            // LBA damage is capped to 300
    "?", "C100"             // Any other damage type is capped to 100
];

PointsChanged() // Called after all damage is processed
{
    string newText = "[C2A+LBA]\n";
    integer n = 10;
    do
    {
        if (points > ((10 - n) * MAX_POINTS / 10)) newText += "⬛";
        else newText += "⬜";
    }
    while (--n);
    newText +=  " " + (string)llFloor(points) + " / " + (string)llRound(MAX_POINTS);
    vector textColor = <1,1,0>; // default color
    if (points == MAX_POINTS) textColor = <0,1,0>; // 100% points
    else if (points / MAX_POINTS < 0.2) textColor = <1,0,0>; // 20% points or below
    llSetLinkPrimitiveParamsFast(TEXT_LINK, [PRIM_TEXT, newText, textColor, 1]);
    if (points == 0)
    {
        llMessageLinked(LINK_SET, 0, "die", "");
        llSleep(1);
        llDie();
    }
}

HitReport(key objectKey, key ownerKey, float rawDamage, float finalDamage) // Called after each individual damage
{
    // Report hits to owner from here, if you want. Maybe filter by amount of damage received?
}

    /*=====================================================================
    Unless making your own edition, do not change anything below this line.
    =====================================================================*/

string c2aName;
float points;
integer listenId;
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
    TakeDamage(0);
}
TakeDamage(float amount)
{
    points -= amount;
    if (points < 0) points = 0;
    else if (points > MAX_POINTS) points = MAX_POINTS;
    llSetObjectDesc("LBA.v.[C2A LBA v0.1.0:" + c2aName + "]," + (string)llFloor(points) + ","
        + (string)llRound(MAX_POINTS));
    llSetLinkPrimitiveParamsFast(LINK_THIS, [PRIM_HEALTH, points]);
    PointsChanged();
}
float ProcessDamage(float amount, string type)
{
    integer i;
    integer t = llGetListLength(DAMAGE_RULES);
    for (; i < t; i += 2)
    {
        list ruleTypes = llCSV2List(llList2String(DAMAGE_RULES, i));
        if ((string)ruleTypes == "?" || llListFindList(ruleTypes, [type]) != -1)
        {
            list ruleModifiers = llCSV2List(llList2String(DAMAGE_RULES, i + 1));
            integer x;
            integer y = llGetListLength(ruleModifiers);
            for (; x < y; x++)
            {
                string mod = llList2String(ruleModifiers, x);
                integer rule = llSubStringIndex("XDCF*+-&%", llGetSubString(mod, 0, 0));
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
                else if (rule == 8) // %: chance
                {
                    if (llFrand(100) > value) x = y; // stop processing more modifiers
                }
            }
            i = t;
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
        }
        else llSetLinkPrimitiveParamsFast(LINK_SET, [PRIM_SCRIPTED_SIT_ONLY, TRUE]);
        Init(0);
    }
    on_rez(integer p)
    {
        if (p) Init(p);
        else if (llGetObjectPermMask(MASK_OWNER) != PERM_ALL)
        {
            // If you don't have full permissions, you shouldn't be rezzing this manually.
            llSleep(5);
            llDie();
        }
    }
    changed(integer c)
    {
        if (c & CHANGED_REGION)
        {
            llListenRemove(listenId);
            integer lbaChannel = (integer)("0x" + llGetSubString(llMD5String((string)llGetKey(), 0), 0, 3));
            listenId = llListen(lbaChannel, "", "", "");
        }
    }
    final_damage(integer n)
    {
        float totalDamage;
        while (n--)
        {
            list damageInfo = llDetectedDamage(n);
            float amount = llList2Float(damageInfo, 0) / 100;
            integer type = llList2Integer(damageInfo, 1);
            float finalDamage = ProcessDamage(amount, (string)type);
            totalDamage += finalDamage;
            HitReport(llDetectedKey(n), llDetectedOwner(n), amount, finalDamage);
        }
        TakeDamage(totalDamage);
    }
    listen(integer channel, string name, key id, string text)
    {
        if (channel == -2453997) // C2A channel
        {
            if (text == "c2a-rules") llRegionSayTo(id, channel, "c2a-rules:" + llDumpList2String(DAMAGE_RULES, "|"));
            else if (text == "c2a-type") llRegionSayTo(id, channel, "c2a-type:basic");
        }
        else // LBA channel
        {
            list params = llCSV2List(text);
            if (llList2Key(params, 0) == llGetKey())
            {
                float amount = llList2Float(params, 1);
                float finalDamage = ProcessDamage(amount, "L");
                TakeDamage(amount);
                key ownerKey = llGetOwnerKey(id);
                if (ownerKey == id) ownerKey = "";
                HitReport(id, ownerKey, amount, finalDamage);
            }
        }
    }
}

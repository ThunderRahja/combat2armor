/*
    C2A-simple.lsl
        https://github.com/ThunderRahja/combat2armor/blob/main/C2A-simple.lsl
    
    This script is licensed under GNU GPL 3.0. You can read the license here:
        https://github.com/ThunderRahja/combat2armor/blob/main/LICENSE
*/

integer TEXT_LINK = LINK_THIS;
float MAX_POINTS = 100;

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

    /*=====================================================================
    Unless making your own edition, do not change anything below this line.
    =====================================================================*/

string c2aName;
float points;
integer listenId;
Init(float startPoints) // Call only from state_entry or on_rez
{
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
    if (amount > MAX_POINTS) amount = MAX_POINTS;
    else if (amount < -MAX_POINTS) amount = -MAX_POINTS;
    return amount;
}

default
{
    state_entry()
    {
        llSetLinkPrimitiveParamsFast(LINK_SET, [PRIM_SCRIPTED_SIT_ONLY, TRUE]);
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
            float amount = llList2Float(damageInfo, 0);
            integer type = llList2Integer(damageInfo, 1);
            float finalDamage = ProcessDamage(amount, (string)type);
            totalDamage += finalDamage;
        }
        TakeDamage(totalDamage);
    }
    listen(integer channel, string name, key id, string text)
    {
        if (channel == -2453997) // C2A channel
        {
            if (text == "c2a-rules") llRegionSayTo(id, channel, "c2a-rules:");
            else if (text == "c2a-type") llRegionSayTo(id, channel, "c2a-type:simple");
        }
        else // LBA channel
        {
            list params = llCSV2List(text);
            if (llList2Key(params, 0) == llGetKey())
            {
                float amount = llList2Float(params, 1);
                float finalDamage = ProcessDamage(amount, "L");
                TakeDamage(amount);
            }
        }
    }
}

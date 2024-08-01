/*
    C2A-bare.lsl
        https://github.com/ThunderRahja/combat2armor/blob/main/C2A-bare.lsl
    
    This script is licensed under GNU GPL 3.0. You can read the license here:
        https://github.com/ThunderRahja/combat2armor/blob/main/LICENSE
*/

float MAX_POINTS = 100;
float points;
string descPrefix = "LBA.v.[C2A LBA v0.1.0:"; // + c2aName + "]," <-- added when c2aName is generated


TakeDamage(float amount)
{
    points -= amount;
    
    // Limit points, can't be deader than already dead. However MAX_POINTS logic here could be tweaked to allow overhealth repairs, e.g. (points > MAX_POINTS * 1.25) points = MAX_POINTS * 1.25; // +25% overhealth
    if (points < 0) points = 0;
    else if (points > MAX_POINTS) points = MAX_POINTS;
    
    // Floor/round and stringify the points, used in description and hover text
    string current = (string)llFloor(points);
    string maximum = (string)llRound(MAX_POINTS);
    
    // Tweak hover text color based on the points vs max
    vector color = <1,1,0>; // Amber for ≥20% points
    if (points >= MAX_POINTS * 0.9) color = <0,1,0>; // Green at ≥90% points
    else if (points / MAX_POINTS < 0.2) color = <1,0,0>; // Diving into red! <20% points
    
    llSetLinkPrimitiveParamsFast(LINK_THIS, [
        PRIM_HEALTH, points,
        PRIM_DESC, descPrefix + current + "," + maximum,
        PRIM_TEXT, "[C2A+LBA]\n" + current + " / " + maximum, color, 1.0
    ]);
    
    if (points == 0) state dead;
}


default
{
    state_entry()
    {
        points = MAX_POINTS; // Restore to full health
        
        llSetLinkPrimitiveParamsFast(LINK_SET, [
            PRIM_SCRIPTED_SIT_ONLY, TRUE, // Unless a free sit target, don't allow sitting there
            PRIM_SIT_FLAGS,
                SIT_FLAG_NO_COLLIDE // Disable avatar collision volume
            |   SIT_FLAG_NO_DAMAGE // Do not distribute damage to agents 
        ]);
        
        // Listen on LBA channel for backwards compatibility
        integer lbaChannel = (integer)("0x"+llGetSubString(llMD5String((string)llGetKey(),0),0,3));
        llListen(lbaChannel, "", "", "");
        
        // Generate a unique name for the C2A channel
        string c2aName;
        integer n = 8;
        while (n--) c2aName += llChar(llFloor(llFrand(26)) + 65);
        llListen(-2453997, c2aName, "", "");
        descPrefix += c2aName + "],"; // Append it to the description prefix
        
        // To update object description, health and hover text all in one go
        TakeDamage(0.0);
    }
    
    on_rez(integer param)
    {
        // We have a new object key - reset script to generate LBA channel and set initial state
        llResetScript();
    }
    
    /*
    on_damage(integer count)
    {
        NOTE: Barebones version -- usually we'd do damage adjustments here by
        damage type (Combat2) according to the C2A damage rules data!
    }
    */
    
    final_damage(integer count)
    {
        float totalDamage;
        while (count--)
        {
            list damage = llDetectedDamage(count);
            float amount = llList2Float(damage, 0);
            totalDamage += amount;
        }
        
        TakeDamage(totalDamage);
    }
    
    listen(integer channel, string name, key identifier, string text)
    {
        if (channel == -2453997) // C2A channel
        {
            // NOTE: Barebones version -- usually c2a-rules would share the C2A damage rules data!
            if (text == "c2a-rules") llRegionSayTo(identifier, channel, "c2a-rules:");
            else if (text == "c2a-type") llRegionSayTo(identifier, channel, "c2a-type:simple");
        }
        
        else // LBA channel
        {
            list params = llCSV2List(text);
            if (llList2Key(params, 0) == llGetKey())
            {
                float amount = llList2Float(params, 1);
                /*
                    NOTE: Barebones version -- usually we'd process here based on
                    damage type (LBA) according to the C2A damage rules data!
                */
                TakeDamage(amount);
            }
        }
    }
}


state dead
{
    state_entry()
    {
        // We are dead, jim
        
        // Code your dead routine as you wish!
        llMessageLinked(LINK_SET, 0, "die", "");
        llSleep(1.0);
        llDie();
        
        // If you wish to respawn you can replace llDie(); with state default;
    }
}

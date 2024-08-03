/*
    explosion.lsl
        https://github.com/ThunderRahja/combat2armor/blob/main/weapons/explosion.lsl
    
    This script is licensed under GNU GPL 3.0. You can read the license here:
        https://github.com/ThunderRahja/combat2armor/blob/main/LICENSE
    
    This script is activated by rezzing with a non-zero param. Change the below ALL_CAPS variables for configuration.
*/

float CRIT_RADIUS = 5; // range at which critical damage is received
float EFFECT_RADIUS = 7; // range at which high to low damage is received
integer DAMAGE_TYPE = DAMAGE_TYPE_FORCE; // damage type to send
float OBJECT_DAMAGE_CRIT = 500; // damage received in critical (lethal) range, for objects (divided by 100 for LBA)
float OBJECT_DAMAGE_HIGH = 400; // damage received just outside of critical range
float OBJECT_DAMAGE_LOW = 100; // damage received just inside of effect radius
float OBJECT_DAMAGE_CURVE = 1; // 1: linear falloff; >1: exponential falloff starting gradually; <1: starting steeply
float AVATAR_DAMAGE_CRIT = 100; // same as above, but for avatars
float AVATAR_DAMAGE_HIGH = 51;
float AVATAR_DAMAGE_LOW = 10;
float AVATAR_DAMAGE_CURVE = 1;

integer sensorNum; // 1 = sweep for avatars, 2 = sweep for objects
list seatsHit; // list of hits recorded from seated avatars

float DamageWithFalloff(float critRange, float damageRange, float damageCrit, float damageHigh, float damageLow, float curve, float distance)
{   // damage falloff with optional curve; curve should be >0
    if (distance < critRange) return damageCrit;
    if (distance > damageRange) return 0;
    return damageHigh - (damageHigh - damageLow) * llPow((distance - critRange) / (damageRange - critRange),
        curve);
}

Explode()
{
    // Play sounds, particles, animations, etc. here
    sensorNum = 0;
    seatsHit = [];
    llSensor("", NULL_KEY, AGENT, EFFECT_RADIUS, PI); // sensor for avatars
}
Die()
{
    llSleep(1);
    llDie();
}

default
{
    on_rez(integer p)
    {
        if (p) Explode();
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
    sensor(integer t)
    {
        sensorNum++;
        vector myPos = llGetPos();
        if (sensorNum == 1) // agent sweep
        {
            llSensor("", NULL_KEY, SCRIPTED, EFFECT_RADIUS * 2, PI); // sensor for objects, doubled to find larger ones
            list hitList;
            integer n;
            for (; n < t; n++)
            {
                key agentKey = llDetectedKey(n);
                vector agentPos = llDetectedPos(n);
                key agentRoot = llList2Key(llGetObjectDetails(agentKey, [OBJECT_ROOT]), 0); // different if sitting
                if (agentKey != agentRoot) // agent is sitting, store seat's key and agent's pos
                {
                    if (llListFindList(seatsHit, [agentRoot]) == -1) seatsHit += [agentRoot, agentPos];
                }
                else // agent is not sitting
                {
                    list raycast = llCastRay(myPos, agentPos, [RC_REJECT_TYPES, RC_REJECT_AGENTS
                        | RC_REJECT_PHYSICAL]);
                    integer blocked = llList2Integer(raycast, -1);
                    if (blocked > 0) // something was in the way, check if it's phantom
                    {
                        if (llList2Integer(llGetObjectDetails(llList2Key(raycast, 0), [OBJECT_PHANTOM]), 0))
                            blocked = 0; // a raycast blocker was detected; assume clear line of sight
                    }
                    if (blocked <= 0) // clear line of sight to avatar
                    {
                        float dist = llVecDist(myPos, agentPos);
                        float damage = DamageWithFalloff(CRIT_RADIUS, EFFECT_RADIUS, AVATAR_DAMAGE_CRIT,
                            AVATAR_DAMAGE_HIGH, AVATAR_DAMAGE_LOW, AVATAR_DAMAGE_CURVE, dist);
                        if (damage > 0)
                        {
                            string agentName = llDetectedName(n);
                            if (llGetSubString(agentName, -9, -1) == " Resident")
                                agentName = llDeleteSubString(agentName, -9, -1);
                            llDamage(agentKey, damage, DAMAGE_TYPE); // send damage to avatar
                            // append damage amount to name, if not critical:
                            if (damage != AVATAR_DAMAGE_CRIT) agentName += " (" + (string)llRound(damage) + ")";
                            hitList += [agentName]; // add name to list for reporting hits
                        }
                    }
                }
            }
            if (hitList) llOwnerSay("Hit: " + llList2CSV(hitList)); // report any hits
        }
        else if (sensorNum == 2) // object sweep
        {
            integer checkSeats;
            integer n = t;
            while (n--)
            {
                key objectKey;
                vector objectPos;
                integer seat;
                if (!checkSeats) // first, go through sensor results
                {
                    objectKey = llDetectedKey(n);
                    objectPos = llDetectedPos(n);
                    if ((seat = llListFindList(seatsHit, [objectKey])) != -1)
                    {
                        seatsHit = llDeleteSubList(seatsHit, seat, seat + 1); // deal with this seat now
                        seat = 1;
                    }
                    else seat = 0;
                }
                else // second, go through seats detected from agent sweep
                {
                    objectKey = llList2Key(seatsHit, n * 2);
                    objectPos = llList2Vector(seatsHit, n * 2 + 1);
                    seat = 1;
                }
                float dist = llVecDist(myPos, objectPos);
                list raycast = llCastRay(myPos, objectPos, [RC_REJECT_TYPES, RC_REJECT_AGENTS | RC_REJECT_PHYSICAL,
                    RC_DATA_FLAGS, RC_GET_ROOT_KEY]);
                integer blocked = llList2Integer(raycast, -1);
                if (blocked > 0) // something was detected
                {
                    key hitKey = llList2Key(raycast, 0);
                    if (hitKey == objectKey) // the target was hit by a ray; clear line of sight
                    {
                        dist = llVecDist(myPos, llList2Vector(raycast, 1)); // use distance to surface hit
                        blocked = 0;
                    }
                    else if (llList2Integer(llGetObjectDetails(hitKey, [OBJECT_PHANTOM]), 0))
                        blocked = 0; // a raycast blocker was detected; assume clear line of sight
                }
                if (blocked <= 0) // clear line of sight to object
                {
                    float damage = DamageWithFalloff(CRIT_RADIUS, EFFECT_RADIUS, OBJECT_DAMAGE_CRIT,
                        OBJECT_DAMAGE_HIGH, OBJECT_DAMAGE_LOW, OBJECT_DAMAGE_CURVE, dist);
                    if (damage > 0)
                    {
                        list objectDetails = llGetObjectDetails(objectKey, [OBJECT_DESC, OBJECT_HEALTH]);
                        string objectDesc = llList2String(objectDetails, 0);
                        if (llSubStringIndex(objectDesc, "[C2A ") != -1) // object is C2A
                        {
                            llDamage(objectKey, damage, DAMAGE_TYPE);
                        }
                        else if (llGetSubString(objectDesc, 0, 5) == "LBA.v.") // object is LBA
                        {
                            integer chan = (integer)("0x" + llGetSubString(llMD5String((string)objectKey, 0), 0, 3));
                            llRegionSayTo(objectKey, chan, (string)objectKey + "," + (string)llCeil(damage / 100));
                        }
                        else if (seat || llList2Integer(objectDetails, 1)) // object is a seat or has health
                        {
                            llDamage(objectKey, damage, DAMAGE_TYPE);
                        }
                    }
                }
                if (n == 0) // done with last in set
                {
                    if (!checkSeats)
                    {
                        checkSeats = 1; // done with sensor, check seats now
                        n = llGetListLength(seatsHit) / 2; 
                    }
                }
            }
            Die();
        }
    }
    no_sensor()
    {
        sensorNum++;
        if (sensorNum == 1)
        {
            llSensor("", NULL_KEY, SCRIPTED, EFFECT_RADIUS * 2, PI); // sensor for objects, doubled to find larger ones
        }
        else if (sensorNum == 2)
        {
            Die();
        }
    }
}

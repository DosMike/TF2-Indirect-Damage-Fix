#include <sourcemod>
#include <sdkhooks>

#pragma newdecls required
#pragma semicolon 1

//if you want props to be angry at the attacker for longer, increase this time (in sec)
#define MAX_PHYS_DAMAGE_TIME 10.0

#define PLUGIN_VERSION "22w11a"
#define MAX_EDICTS 2048

public Plugin myinfo = {
	name = "[TF2] Indirect Damage Fix",
	author = "reBane",
	description = "Fix Killings people with Physic Objects not giving you credit",
	version = PLUGIN_VERSION,
	url = "N/A"
}

enum struct EntityInteraction {
	int entref;
	int userid;
	float time;
	int GetEntity() {
		return EntRefToEntIndex(this.entref);
	}
	int GetClient() {
		return GetClientOfUserId(this.userid);
	}
	float InteractionDelay() {
		return GetGameTime()-this.time;
	}
}
ArrayList interactions;

public void OnPluginStart() {
	interactions = new ArrayList(sizeof(EntityInteraction));
}
public void OnMapStart() {
	interactions.Clear();
	
	char classname[64];
	for (int ent=1; ent<MAX_EDICTS; ent++) {
		if (!IsValidEdict(ent)) continue;
		GetEntityClassname(ent, classname, sizeof(classname));
		OnEntityCreated(ent, classname);
	}
}
public void OnMapEnd() {
	interactions.Clear();
}


public void OnEntityCreated(int entity, const char[] classname) {
	if (StrContains(classname,"prop_physics")==0 || StrEqual(classname,"func_physbox")) {
		SDKHook(entity, SDKHook_TraceAttackPost, OnSDKTraceAttackPost);
	} else if (StrEqual(classname,"player")) {
		// Order is as follows:
		// SDKHook_OnTakeDamage, SDKHook_OnTakeDamageAlive, SDKHook_OnTakeDamageAlivePost, SDKHook_OnTakeDamagePost
		// So by modifying OTD, Protective plugins can react to our changes in OTDAlive and still block it there.
		SDKHook(entity, SDKHook_OnTakeDamage, OnSDKTakeDamage);
	}
}

public void OnSDKTraceAttackPost(int prop, int attacker, int inflictor, float damage, int damagetype, int ammotype, int hitbox, int hitgroup) {
	if (IsValidClient(attacker)) {
		int propref = EntIndexToEntRef(prop);
		int attackerid = GetClientUserId(attacker);
		int index = interactions.FindValue(propref, EntityInteraction::entref);
		EntityInteraction data;
		if (index >= 0) {
			interactions.GetArray(index, data);
			data.userid = attackerid;
			data.time = GetGameTime();
			interactions.SetArray(index, data);
		} else {
			data.entref = propref;
			data.userid = attackerid;
			data.time = GetGameTime();
			interactions.PushArray(data);
		}
	}
}

public void OnEntityDestroyed(int entity) {
	// this sometimes gets refs
	int propref = entity >= 0 ? EntIndexToEntRef(entity) : entity;
	int at = interactions.FindValue(propref, EntityInteraction::entref);
	if (at>=0) interactions.Erase(at);
}

public Action OnSDKTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype) {
	if (IsValidClient(attacker,false,false) || attacker != inflictor) return Plugin_Continue;
	int entref = EntIndexToEntRef(attacker);
	if (entref == INVALID_ENT_REFERENCE) return Plugin_Continue;
	int index = interactions.FindValue(entref, EntityInteraction::entref);
	if (index < 0) return Plugin_Continue;
	EntityInteraction data;
	interactions.GetArray(index, data);
	if (data.InteractionDelay()<MAX_PHYS_DAMAGE_TIME) attacker = data.GetClient();
	else interactions.Erase(index); //make subsequent calls a bit quicker by removing this stale entry
	return Plugin_Changed;
}

stock bool IsValidClient(int client, bool requireIngame=true, bool requireHasTeam=true, bool allowBots=true, bool requireAlive=false) {
	return 1<=client<=MaxClients &&
		(!requireIngame || IsClientInGame(client)) &&
		(!requireHasTeam || GetClientTeam(client)>1) &&
		(allowBots || !IsFakeClient(client)) &&
		(!requireAlive || IsPlayerAlive(client));
}

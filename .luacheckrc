
files["settings.lua"] = {
  read_globals = {
    -- "data/scripts/lib/mod_settings.lua"
    "MOD_SETTING_SCOPE_RUNTIME",
  }
}

files["files/panel.lua"] = {
  read_globals = {
    -- "mods/world_radar/config.lua"
    "MOD_ID",
    "CONF",
    "conf_get",
    "conf_set",
    -- "mods/world_radar/files/lib/utility.lua"
    "generate_traceback",
  }
}

files["files/radar.lua"] = {
  read_globals = {
    -- "data/scripts/lib/utilities.lua"
    "get_magnitude",
    "vec_normalize",
    "get_players",
  }
}

files["files/utility/orbs.lua"] = {
  read_globals = {
    -- "data/scripts/lib/utilities.lua"
    "orb_map_get",
  }
}

files["files/utility/spell.lua"] = {
  read_globals = {
    -- "data/scripts/gun/gun_enums.lua"
    "ACTION_TYPE_PROJECTILE",
    "ACTION_TYPE_STATIC_PROJECTILE",
    "ACTION_TYPE_MODIFIER",
    "ACTION_TYPE_DRAW_MANY",
    "ACTION_TYPE_MATERIAL",
    "ACTION_TYPE_OTHER",
    "ACTION_TYPE_UTILITY",
    "ACTION_TYPE_PASSIVE",
  }
}

files["files/utility/entity.lua"] = {
  read_globals = {
    -- "data/scripts/lib/utilities.lua"
    "get_players",
  }
}

files["files/utility/treasure_chest.lua"] = {
  read_globals = {
    -- "data/scripts/lib/utilities.lua"
    "random_from_array",
    -- "data/scripts/gun/gun_enums.lua"
    "ACTION_TYPE_UTILITY",
    "ACTION_TYPE_MODIFIER",
    -- "data/scripts/gun/gun_actions.lua"
    "actions",
  }
}

files["files/panels/info.lua"] = {
  read_globals = {
    -- "data/scripts/lib/utilities.lua"
    "get_players",
    "check_parallel_pos",
    -- "mods/world_radar/config.lua"
    "MOD_ID",
    "CONF",
    "conf_get",
    "conf_set",
    "conf_toggle",
    -- "mods/world_radar/files/utility/biome.lua"
    "get_biome_data",
    "biome_is_default",
    "biome_is_common",
    "biome_modifier_get",
    -- "mods/world_radar/files/utility/entity.lua"
    "is_child_of",
    "entity_is_item",
    "entity_is_enemy",
    "item_get_name",
    "enemy_get_name",
    "animal_build_name",
    "get_display_name",
    "entity_get_lookup_key",
    "get_health",
    "entity_match",
    "get_with_tags",
    "distance_from",
    -- "mods/world_radar/files/utility/material.lua"
    "container_get_contents",
    "container_get_capacity",
    "material_get_icon",
    "generate_material_tables",
    "get_material_data_for",
    -- "mods/world_radar/files/utility/spell.lua"
    "get_spell_list",
    "get_spell_table",
    "card_get_spell",
    "wand_get_spells",
    "spell_is_always_cast",
    "spell_get_data",
    "spell_get_name",
    "spell_get_icon",
    "wand_get_icon",
    "action_lookup",
    -- "mods/world_radar/files/utility/treasure_chest.lua"
    "entity_is_chest",
    "chest_get_lookup_data",
    "entity_get_spawn_pos",
    "chest_get_rewards",
    "format_rewards",
    "REWARD",
    -- "mods/world_radar/files/utility/orbs.lua"
    "Orbs",
    "world_get_name",
    "make_distance_sorter",
    -- "mods/world_radar/files/utility/eval.lua"
    "Eval",
    -- "mods/world_radar/files/radar.lua"
    "Radar",
    "RADAR_KIND_SPELL",
    "RADAR_KIND_ENTITY",
    "RADAR_KIND_MATERIAL",
    "RADAR_KIND_ITEM",
    "RADAR_ORB",
    -- "mods/world_radar/files/lib/utility.lua"
    "aggregate",
    "table_clear",
    "table_empty",
    "table_has_entry",
    "table_extend",
    "table_concat",
    "split_string",
    "first_of",
    "stats_check_spell",
    "generate_traceback",
  },
}

files["init.lua"] = {
  read_globals = {
    -- "mods/world_radar/config.lua"
    "MOD_ID",
    "CONF",
    "conf_get",
    -- "mods/world_radar/files/utility/material.lua"
    "generate_material_tables",
    -- "mods/world_radar/files/lib/profiler.lua"
    "Profiler",
  },
}

read_globals = {
  "load_imgui",
  "print_error",
  "async",
  "wait",
  "EntityLoad",
  "EntityLoadEndGameItem",
  "EntityLoadCameraBound",
  "EntityLoadToEntity",
  "EntitySave",
  "EntityCreateNew",
  "EntityKill",
  "EntityGetIsAlive",
  "EntityAddComponent",
  "EntityRemoveComponent",
  "EntityGetAllComponents",
  "EntityGetComponent",
  "EntityGetFirstComponent",
  "EntityGetComponentIncludingDisabled",
  "EntityGetFirstComponentIncludingDisabled",
  "EntitySetTransform",
  "EntityApplyTransform",
  "EntityGetTransform",
  "EntityAddChild",
  "EntityGetAllChildren",
  "EntityGetParent",
  "EntityGetRootEntity",
  "EntityRemoveFromParent",
  "EntitySetComponentsWithTagEnabled",
  "EntitySetComponentIsEnabled",
  "EntityGetName",
  "EntitySetName",
  "EntityGetTags",
  "EntityGetWithTag",
  "EntityGetInRadius",
  "EntityGetInRadiusWithTag",
  "EntityGetClosest",
  "EntityGetClosestWithTag",
  "EntityGetWithName",
  "EntityAddTag",
  "EntityRemoveTag",
  "EntityHasTag",
  "EntityGetFilename",
  "ComponentGetValue",
  "ComponentGetValueBool",
  "ComponentGetValueInt",
  "ComponentGetValueFloat",
  "ComponentGetValueVector2",
  "ComponentSetValue",
  "ComponentSetValueVector2",
  "ComponentSetValueValueRange",
  "ComponentSetValueValueRangeInt",
  "ComponentSetMetaCustom",
  "ComponentGetMetaCustom",
  "ComponentObjectGetValue",
  "ComponentObjectGetValueBool",
  "ComponentObjectGetValueInt",
  "ComponentObjectGetValueFloat",
  "ComponentObjectSetValue",
  "ComponentAddTag",
  "ComponentRemoveTag",
  "ComponentHasTag",
  "ComponentGetValue2",
  "ComponentSetValue2",
  "ComponentObjectGetValue2",
  "ComponentObjectSetValue2",
  "EntityAddComponent2",
  "ComponentGetVectorSize",
  "ComponentGetVectorValue",
  "ComponentGetVector",
  "ComponentGetIsEnabled",
  "ComponentGetMembers",
  "ComponentObjectGetMembers",
  "ComponentGetTypeName",
  "GetUpdatedEntityID",
  "GetUpdatedComponentID",
  "SetTimeOut",
  "RegisterSpawnFunction",
  "SpawnActionItem",
  "SpawnStash",
  "SpawnApparition",
  "LoadEntityToStash",
  "AddMaterialInventoryMaterial",
  "GetMaterialInventoryMainMaterial",
  "GameScreenshake",
  "GameOnCompleted",
  "GameGiveAchievement",
  "GameDoEnding2",
  "GetParallelWorldPosition",
  "BiomeMapLoad_KeepPlayer",
  "BiomeMapLoad",
  "BiomeSetValue",
  "BiomeGetValue",
  "BiomeObjectSetValue",
  "BiomeVegetationSetValue",
  "BiomeMaterialSetValue",
  "BiomeMaterialGetValue",
  "GameIsIntroPlaying",
  "GameGetIsGamepadConnected",
  "GameGetWorldStateEntity",
  "GameGetPlayerStatsEntity",
  "GameGetOrbCountAllTime",
  "GameGetOrbCountThisRun",
  "GameGetOrbCollectedThisRun",
  "GameGetOrbCollectedAllTime",
  "GameClearOrbsFoundThisRun",
  "GameGetOrbCountTotal",
  "CellFactory_GetName",
  "CellFactory_GetType",
  "CellFactory_GetUIName",
  "CellFactory_GetAllLiquids",
  "CellFactory_GetAllSands",
  "CellFactory_GetAllGases",
  "CellFactory_GetAllFires",
  "CellFactory_GetAllSolids",
  "CellFactory_GetTags",
  "GameGetCameraPos",
  "GameSetCameraPos",
  "GameSetCameraFree",
  "GameGetCameraBounds",
  "GameRegenItemAction",
  "GameRegenItemActionsInContainer",
  "GameRegenItemActionsInPlayer",
  "GameKillInventoryItem",
  "GamePickUpInventoryItem",
  "GameGetAllInventoryItems",
  "GameDropAllItems",
  "GameDropPlayerInventoryItems",
  "GameDestroyInventoryItems",
  "GameIsInventoryOpen",
  "GameTriggerGameOver",
  "LoadPixelScene",
  "LoadBackgroundSprite",
  "GameCreateCosmeticParticle",
  "GameCreateParticle",
  "GameCreateSpriteForXFrames",
  "GameShootProjectile",
  "EntityInflictDamage",
  "EntityIngestMaterial",
  "EntityRemoveIngestionStatusEffect",
  "EntityAddRandomStains",
  "EntitySetDamageFromMaterial",
  "EntityRefreshSprite",
  "EntityGetWandCapacity",
  "GamePlayAnimation",
  "GameGetVelocityCompVelocity",
  "GameGetGameEffect",
  "GameGetGameEffectCount",
  "LoadGameEffectEntityTo",
  "GetGameEffectLoadTo",
  "SetPlayerSpawnLocation",
  "UnlockItem",
  "GameGetPotionColorUint",
  "EntityGetFirstHitboxCenter",
  "Raytrace",
  "RaytraceSurfaces",
  "RaytraceSurfacesAndLiquiform",
  "RaytracePlatforms",
  "FindFreePositionForBody",
  "GetSurfaceNormal",
  "DoesWorldExistAt",
  "StringToHerdId",
  "HerdIdToString",
  "GetHerdRelation",
  "EntityGetHerdRelation",
  "EntityGetHerdRelationSafe",
  "GenomeSetHerdId",
  "EntityGetClosestWormAttractor",
  "EntityGetClosestWormDetractor",
  "GamePrint",
  "GamePrintImportant",
  "DEBUG_GetMouseWorld",
  "DEBUG_MARK",
  "GameGetFrameNum",
  "GameGetRealWorldTimeSinceStarted",
  "IsPlayer",
  "IsInvisible",
  "GameIsDailyRun",
  "GameIsDailyRunOrDailyPracticeRun",
  "GameIsModeFullyDeterministic",
  "GlobalsSetValue",
  "GlobalsGetValue",
  "MagicNumbersGetValue",
  "SetWorldSeed",
  "SessionNumbersGetValue",
  "SessionNumbersSetValue",
  "SessionNumbersSave",
  "AutosaveDisable",
  "StatsGetValue",
  "StatsGlobalGetValue",
  "StatsBiomeGetValue",
  "StatsBiomeReset",
  "StatsLogPlayerKill",
  "CreateItemActionEntity",
  "GetRandomActionWithType",
  "GetRandomAction",
  "GameGetDateAndTimeUTC",
  "GameGetDateAndTimeLocal",
  "GameEmitRainParticles",
  "GameCutThroughWorldVertical",
  "BiomeMapSetSize",
  "BiomeMapGetSize",
  "BiomeMapSetPixel",
  "BiomeMapGetPixel",
  "BiomeMapConvertPixelFromUintToInt",
  "BiomeMapLoadImage",
  "BiomeMapLoadImageCropped",
  "BiomeMapGetVerticalPositionInsideBiome",
  "BiomeMapGetName",
  "SetRandomSeed",
  "Random",
  "Randomf",
  "RandomDistribution",
  "RandomDistributionf",
  "ProceduralRandom",
  "ProceduralRandomf",
  "ProceduralRandomi",
  "PhysicsAddBodyImage",
  "PhysicsAddBodyCreateBox",
  "PhysicsAddJoint",
  "PhysicsApplyForce",
  "PhysicsApplyTorque",
  "PhysicsApplyTorqueToComponent",
  "PhysicsApplyForceOnArea",
  "PhysicsRemoveJoints",
  "PhysicsSetStatic",
  "PhysicsGetComponentVelocity",
  "PhysicsGetComponentAngularVelocity",
  "PhysicsBody2InitFromComponents",
  "PhysicsVecToGameVec",
  "GameVecToPhysicsVec",
  "LooseChunk",
  "AddFlagPersistent",
  "RemoveFlagPersistent",
  "HasFlagPersistent",
  "GameAddFlagRun",
  "GameRemoveFlagRun",
  "GameHasFlagRun",
  "GameTriggerMusicEvent",
  "GameTriggerMusicCue",
  "GameTriggerMusicFadeOutAndDequeueAll",
  "GamePlaySound",
  "GameEntityPlaySound",
  "GameEntityPlaySoundLoop",
  "GameSetPostFxParameter",
  "GameUnsetPostFxParameter",
  "GameTextGetTranslatedOrNot",
  "GameTextGet",
  "GuiCreate",
  "GuiDestroy",
  "GuiStartFrame",
  "GuiOptionsAdd",
  "GuiOptionsRemove",
  "GuiOptionsClear",
  "GuiOptionsAddForNextWidget",
  "GuiColorSetForNextWidget",
  "GuiZSet",
  "GuiZSetForNextWidget",
  "GuiIdPush",
  "GuiIdPushString",
  "GuiIdPop",
  "GuiAnimateBegin",
  "GuiAnimateEnd",
  "GuiAnimateAlphaFadeIn",
  "GuiAnimateScaleIn",
  "GuiText",
  "GuiTextCentered",
  "GuiImage",
  "GuiImageNinePiece",
  "GuiButton",
  "GuiImageButton",
  "GuiSlider",
  "GuiTextInput",
  "GuiBeginAutoBox",
  "GuiEndAutoBoxNinePiece",
  "GuiTooltip",
  "GuiBeginScrollContainer",
  "GuiEndScrollContainer",
  "GuiLayoutBeginHorizontal",
  "GuiLayoutBeginVertical",
  "GuiLayoutAddHorizontalSpacing",
  "GuiLayoutAddVerticalSpacing",
  "GuiLayoutEnd",
  "GuiLayoutBeginLayer",
  "GuiLayoutEndLayer",
  "GuiGetScreenDimensions",
  "GuiGetTextDimensions",
  "GuiGetImageDimensions",
  "GuiGetPreviousWidgetInfo",
  "GameIsBetaBuild",
  "DebugGetIsDevBuild",
  "DebugEnableTrailerMode",
  "GameGetIsTrailerModeEnabled",
  "Debug_SaveTestPlayer",
  "DebugBiomeMapGetFilename",
  "EntityConvertToMaterial",
  "ConvertEverythingToGold",
  "ConvertMaterialEverywhere",
  "ConvertMaterialOnAreaInstantly",
  "GetDailyPracticeRunSeed",
  "ModIsEnabled",
  "ModGetActiveModIDs",
  "ModGetAPIVersion",
  "ModSettingGet",
  "ModSettingSet",
  "ModSettingGetNextValue",
  "ModSettingSetNextValue",
  "ModSettingRemove",
  "ModSettingGetCount",
  "ModSettingGetAtIndex",
  "StreamingGetIsConnected",
  "StreamingGetConnectedChannelName",
  "StreamingGetVotingCycleDurationFrames",
  "StreamingGetRandomViewerName",
  "StreamingGetSettingsGhostsNamedAfterViewers",
  "StreamingSetCustomPhaseDurations",
  "StreamingForceNewVoting",
  "StreamingSetVotingEnabled",
  "ModLuaFileAppend",
  "ModTextFileGetContent",
  "ModTextFileSetContent",
  "ModTextFileWhoSetContent",
  "ModMagicNumbersFileAdd",
  "ModMaterialsFileAdd",
  "ModRegisterAudioEventMappings",
  "ModDevGenerateSpriteUVsForDirectory",
  "RegisterProjectile",
  "RegisterGunAction",
  "RegisterGunShotEffects",
  "BeginProjectile",
  "EndProjectile",
  "BeginTriggerTimer",
  "BeginTriggerHitWorld",
  "BeginTriggerDeath",
  "EndTrigger",
  "SetProjectileConfigs",
  "StartReload",
  "ActionUsesRemainingChanged",
  "ActionUsed",
  "LogAction",
  "OnActionPlayed",
  "OnNotEnoughManaForAction",
  "BaabInstruction",
  "SetValueNumber",
  "GetValueNumber",
  "SetValueInteger",
  "GetValueInteger",
  "SetValueBool",
  "GetValueBool",
  "dofile",
  "dofile_once",
}

-- vim: set filetype=lua:

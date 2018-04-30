Handle g_cvFriendlyFire = INVALID_HANDLE;

CreateCvars() {
    CreateConVar(
        "chillydm_version",
        PLUGIN_VERSION,
        "ChillyDM Plugin Version",
        FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY
    );

    g_cvFriendlyFire = FindConVar("mp_friendlyfire");
}
// Second Life chat logger and Markov conversation-flow viewer.
// Configure RELAY_URL, then place in a parcel object. The owner can use
// /-77553311 status, report, logging on, or logging off.

string RELAY_URL = "https://stimky.info";
integer CONTROL_CHANNEL = -77553311;
integer LOG_PUBLIC_CHAT = TRUE;
integer gListenHandle;
key gOwner;
key gRequest;
integer gRequestsSent;
integer gLogsAccepted;
integer gFailures;

string on_off(integer enabled)
{
    if (enabled)
    {
        return "on";
    }
    return "off";
}

string make_log_entry(string message, key speaker_id, string speaker_name)
{
    vector position = llGetPos();
    return llList2Json(JSON_OBJECT, [
        "avatar_id", (string)speaker_id,
        "avatar_name", speaker_name,
        "captured_by", llKey2Name(gOwner),
        "message", message,
        "sim_name", llGetRegionName(),
        "timestamp", llGetUnixTime(),
        "x_pos", position.x,
        "y_pos", position.y,
        "z_pos", position.z
    ]);
}

integer start_listening()
{
    if (gListenHandle)
    {
        llListenRemove(gListenHandle);
        gListenHandle = 0;
    }
    if (LOG_PUBLIC_CHAT)
    {
        gListenHandle = llListen(0, "", NULL_KEY, "");
    }
    return 0;
}

integer log_message(string message, key speaker_id, string speaker_name)
{
    if (speaker_id == gOwner || message == "" || llGetSubString(message, 0, 0) == "/")
    {
        return 0;
    }
    gRequest = llHTTPRequest(
        RELAY_URL + "/sl_logger",
        [HTTP_METHOD, "POST", HTTP_MIMETYPE, "text/plain", HTTP_VERIFY_CERT, TRUE],
        make_log_entry(message, speaker_id, speaker_name)
    );
    gRequestsSent += 1;
    return 0;
}

integer request_report()
{
    gRequest = llHTTPRequest(RELAY_URL + "/markov_metrics", [HTTP_METHOD, "GET", HTTP_VERIFY_CERT, TRUE], "");
    gRequestsSent += 1;
    return 0;
}

integer show_status()
{
    llOwnerSay("Chat metrics: logging=" + on_off(LOG_PUBLIC_CHAT)
        + " sent=" + (string)gRequestsSent
        + " accepted=" + (string)gLogsAccepted
        + " failures=" + (string)gFailures);
    return 0;
}

default
{
    state_entry()
    {
        gOwner = llGetOwner();
        llListen(CONTROL_CHANNEL, "", gOwner, "");
        start_listening();
        llOwnerSay("Chat metrics ready. Use /" + (string)CONTROL_CHANNEL + " report or status.");
    }

    listen(integer channel, string name, key id, string message)
    {
        if (channel == CONTROL_CHANNEL && id == gOwner)
        {
            message = llToLower(llStringTrim(message, STRING_TRIM));
            if (message == "report") request_report();
            else if (message == "status") show_status();
            else if (message == "logging on") { LOG_PUBLIC_CHAT = TRUE; start_listening(); }
            else if (message == "logging off") { LOG_PUBLIC_CHAT = FALSE; start_listening(); }
            else llOwnerSay("Commands: report, status, logging on, logging off");
            return;
        }
        if (channel == 0 && LOG_PUBLIC_CHAT)
        {
            log_message(message, id, name);
        }
    }

    changed(integer change)
    {
        if (change & CHANGED_OWNER) llResetScript();
    }

    http_response(key request_id, integer status, list metadata, string body)
    {
        if (request_id != gRequest) return;
        if (status != 200)
        {
            gFailures += 1;
            llOwnerSay("Chat metrics request failed: HTTP " + (string)status);
            return;
        }
        if (llJsonGetValue(body, ["conversation_flow_score"]) != JSON_INVALID)
        {
            string score = llJsonGetValue(body, ["conversation_flow_score"]);
            string events = llJsonGetValue(body, ["total_events"]);
            string speakers = llJsonGetValue(body, ["unique_speakers"]);
            string switch_rate = llJsonGetValue(body, ["speaker_switch_rate"]);
            llOwnerSay("Conversation flow " + score + "/100 | events=" + events
                + " speakers=" + speakers + " switch rate=" + switch_rate);
        }
        else
        {
            gLogsAccepted += 1;
        }
    }
}
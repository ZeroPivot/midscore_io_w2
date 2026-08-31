// Second Life chat logger and complete Markov metrics viewer.
// Owner commands on /-77553311: report, status, logging on, logging off.

string RELAY_URL = "https://stimky.info/markov_metrics";
integer CONTROL_CHANNEL = -77553311;
integer LOG_PUBLIC_CHAT = TRUE;
integer MAX_OWNER_MESSAGE_LENGTH = 230;
integer MAX_TRANSITIONS_TO_SHOW = 20;

key gOwner;
integer gControlListenHandle;
integer gPublicListenHandle;
list gPendingLogRequests;
list gPendingReportRequests;
integer gRequestsSent;
integer gLogsAccepted;
integer gFailures;

string on_off(integer enabled)
{
    if (enabled) return "on";
    return "off";
}

integer list_contains_key(list values, key value)
{
    return llListFindList(values, [value]) != -1;
}

list remove_key(list values, key value)
{
    integer index = llListFindList(values, [value]);
    if (index == -1) return values;
    return llDeleteSubList(values, index, index);
}

integer owner_say_chunks(string text)
{
    integer start = 0;
    integer length = llStringLength(text);

    if (length == 0)
    {
        llOwnerSay("(empty response)");
        return 0;
    }
    while (start < length)
    {
        llOwnerSay(llGetSubString(text, start, start + MAX_OWNER_MESSAGE_LENGTH - 1));
        start += MAX_OWNER_MESSAGE_LENGTH;
    }
    return 0;
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

integer start_public_listening()
{
    if (gPublicListenHandle)
    {
        llListenRemove(gPublicListenHandle);
        gPublicListenHandle = 0;
    }
    if (LOG_PUBLIC_CHAT)
    {
        gPublicListenHandle = llListen(0, "", NULL_KEY, "");
    }
    return 0;
}

integer log_message(string message, key speaker_id, string speaker_name)
{
    key request_id;
    if (speaker_id == gOwner || message == "" || llGetSubString(message, 0, 0) == "/")
    {
        return 0;
    }
    request_id = llHTTPRequest(
        RELAY_URL + "/sl_logger",
        [HTTP_METHOD, "POST", HTTP_MIMETYPE, "text/plain", HTTP_VERIFY_CERT, TRUE],
        make_log_entry(message, speaker_id, speaker_name)
    );
    gPendingLogRequests += [request_id];
    gRequestsSent += 1;
    return 0;
}

integer request_report()
{
    key request_id = llHTTPRequest(
        RELAY_URL + "/markov_metrics",
        [HTTP_METHOD, "GET", HTTP_VERIFY_CERT, TRUE],
        ""
    );
    gPendingReportRequests += [request_id];
    gRequestsSent += 1;
    return 0;
}

integer show_status()
{
    llOwnerSay("Chat metrics: logging=" + on_off(LOG_PUBLIC_CHAT)
        + " sent=" + (string)gRequestsSent
        + " accepted=" + (string)gLogsAccepted
        + " pending logs=" + (string)llGetListLength(gPendingLogRequests)
        + " failures=" + (string)gFailures);
    return 0;
}

integer show_report(string body)
{
    string score = llJsonGetValue(body, ["conversation_flow_score"]);
    string events = llJsonGetValue(body, ["total_events"]);
    string speakers = llJsonGetValue(body, ["unique_speakers"]);
    string transitions = llJsonGetValue(body, ["transitions"]);
    string switch_rate = llJsonGetValue(body, ["speaker_switch_rate"]);
    string average_reply = llJsonGetValue(body, ["average_reply_seconds"]);
    integer index = 0;

    if (score == JSON_INVALID)
    {
        owner_say_chunks("Markov metrics returned invalid JSON: " + body);
        return 0;
    }
    if (average_reply == JSON_NULL)
    {
        average_reply = "n/a";
    }
    else
    {
        average_reply += "s";
    }

    owner_say_chunks("Conversation flow " + score + "/100 | events=" + events
        + " speakers=" + speakers + " transitions=" + transitions
        + " switch rate=" + switch_rate + " avg reply=" + average_reply);

    while (index < MAX_TRANSITIONS_TO_SHOW)
    {
        string from = llJsonGetValue(body, ["top_transitions", index, "from"]);
        string to = llJsonGetValue(body, ["top_transitions", index, "to"]);
        string count = llJsonGetValue(body, ["top_transitions", index, "count"]);
        string probability = llJsonGetValue(body, ["top_transitions", index, "probability"]);
        if (from == JSON_INVALID) return 0;
        owner_say_chunks((string)(index + 1) + ". " + from + " -> " + to
            + " | count=" + count + " probability=" + probability);
        index += 1;
    }
    return 0;
}

default
{
    state_entry()
    {
        gOwner = llGetOwner();
        gControlListenHandle = llListen(CONTROL_CHANNEL, "", gOwner, "");
        start_public_listening();
        llOwnerSay("Chat metrics ready. Use /" + (string)CONTROL_CHANNEL
            + " report, status, logging on, or logging off.");
    }

    listen(integer channel, string name, key id, string message)
    {
        if (channel == CONTROL_CHANNEL && id == gOwner)
        {
            message = llToLower(llStringTrim(message, STRING_TRIM));
            if (message == "report") request_report();
            else if (message == "status") show_status();
            else if (message == "logging on") { LOG_PUBLIC_CHAT = TRUE; start_public_listening(); }
            else if (message == "logging off") { LOG_PUBLIC_CHAT = FALSE; start_public_listening(); }
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
        if (list_contains_key(gPendingReportRequests, request_id))
        {
            gPendingReportRequests = remove_key(gPendingReportRequests, request_id);
            if (status != 200)
            {
                gFailures += 1;
                llOwnerSay("Markov metrics request failed: HTTP " + (string)status);
                return;
            }
            show_report(body);
            return;
        }

        if (list_contains_key(gPendingLogRequests, request_id))
        {
            gPendingLogRequests = remove_key(gPendingLogRequests, request_id);
            if (status == 200)
            {
                gLogsAccepted += 1;
            }
            else
            {
                gFailures += 1;
                llOwnerSay("Chat log request failed: HTTP " + (string)status);
            }
        }
    }
}
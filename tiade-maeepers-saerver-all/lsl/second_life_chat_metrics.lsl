// Second Life chat logger and complete Markov metrics viewer.
// Owner commands on /-77553311: report, status, logging on, logging off.

string RELAY_URL = "https://stimky.info";
integer CONTROL_CHANNEL = -77553311;
integer LOG_PUBLIC_CHAT = TRUE;
integer MAX_OWNER_MESSAGE_LENGTH = 230;
integer MAX_TRANSITIONS_TO_SHOW = 8;
integer MAX_SPEAKERS_TO_SHOW = 8;
integer REPORT_REQUEST_TIMEOUT_SECONDS = 45;

key gOwner;
integer gControlListenHandle;
integer gPublicListenHandle;
list gPendingLogRequests;
list gPendingReportRequests;
integer gReportRequestedAt;
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

string json_value_or(string body, list path, string fallback)
{
    string value = llJsonGetValue(body, path);
    if (value == JSON_INVALID || value == JSON_NULL || value == "")
    {
        return fallback;
    }
    return value;
}

string truncate_text(string text, integer max_length)
{
    if (llStringLength(text) <= max_length) return text;
    return llGetSubString(text, 0, max_length - 4) + "...";
}

string format_decimal(string value, integer decimal_places)
{
    integer decimal_index;
    if (value == JSON_INVALID || value == JSON_NULL || value == "") return "n/a";
    value = (string)((float)value);
    decimal_index = llSubStringIndex(value, ".");
    if (decimal_index == -1) return value;
    if (decimal_places == 0)
    {
        return llGetSubString(value, 0, decimal_index - 1);
    }
    return llGetSubString(value, 0, decimal_index + decimal_places);
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
        [HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json", HTTP_VERIFY_CERT, TRUE],
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
    gReportRequestedAt = llGetUnixTime();
    gRequestsSent += 1;
    llOwnerSay("Requesting conversation-flow metrics...");
    return 0;
}

integer show_status()
{
    llOwnerSay("Chat metrics: logging=" + on_off(LOG_PUBLIC_CHAT)
        + " sent=" + (string)gRequestsSent
        + " accepted=" + (string)gLogsAccepted
        + " pending logs=" + (string)llGetListLength(gPendingLogRequests)
        + " pending reports=" + (string)llGetListLength(gPendingReportRequests)
        + " failures=" + (string)gFailures);
    return 0;
}

integer show_report(string body)
{
    string score = json_value_or(body, ["conversation_flow_score"], "0");
    string events = json_value_or(body, ["total_events"], "0");
    string speakers = json_value_or(body, ["unique_speakers"], "0");
    string transitions = json_value_or(body, ["transitions"], "0");
    string switch_rate = format_decimal(json_value_or(body, ["speaker_switch_rate"], "0"), 2);
    string average_reply = json_value_or(body, ["average_reply_seconds"], "n/a");
    integer index = 0;

    if (llJsonValueType(body, []) != JSON_OBJECT)
    {
        owner_say_chunks("Markov metrics returned invalid JSON: " + body);
        return 0;
    }
    if (average_reply != "n/a")
    {
        average_reply = format_decimal(average_reply, 1) + "s";
    }

    owner_say_chunks("FLOW " + score + "/100 | " + events + " messages | "
        + speakers + " speakers | " + transitions + " transitions");
    owner_say_chunks("Switch rate: " + switch_rate + " | Average reply: " + average_reply);

    owner_say_chunks("UNIQUENESS (distinct messages / total)");
    while (index < MAX_SPEAKERS_TO_SHOW)
    {
        string speaker = llJsonGetValue(body, ["speaker_uniqueness", index, "speaker"]);
        string total = llJsonGetValue(body, ["speaker_uniqueness", index, "total_messages"]);
        string unique_count = llJsonGetValue(body, ["speaker_uniqueness", index, "unique_messages"]);
        string unique_percent = format_decimal(llJsonGetValue(body, ["speaker_uniqueness", index, "unique_percent"]), 1);
        if (speaker != JSON_INVALID)
        {
            owner_say_chunks(truncate_text(speaker, 36) + "  " + unique_percent + "% ("
                + unique_count + "/" + total + ")");
        }
        index += 1;
    }

    index = 0;
    while (index < MAX_TRANSITIONS_TO_SHOW)
    {
        string from = llJsonGetValue(body, ["top_transitions", index, "from"]);
        string to = llJsonGetValue(body, ["top_transitions", index, "to"]);
        string count = llJsonGetValue(body, ["top_transitions", index, "count"]);
        string probability = format_decimal(llJsonGetValue(body, ["top_transitions", index, "probability"]), 2);
        if (from == JSON_INVALID) return 0;
        owner_say_chunks((string)(index + 1) + ". " + truncate_text(from, 28)
            + " -> " + truncate_text(to, 28) + "  " + count + "x (" + probability + ")");
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
        llSetTimerEvent(5.0);
        llOwnerSay("Chat metrics ready. Use /" + (string)CONTROL_CHANNEL
            + " report, status, logging on, or logging off.");
    }

    listen(integer channel, string name, key id, string message)
    {
        if (channel == CONTROL_CHANNEL && id == gOwner)
        {
            message = llToLower(llStringTrim(message, STRING_TRIM));
            if (message == "report")
            {
                if (llGetListLength(gPendingReportRequests) > 0)
                {
                    llOwnerSay("A metrics request is already in progress.");
                }
                else
                {
                    request_report();
                }
            }
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

    timer()
    {
        if (llGetListLength(gPendingReportRequests) > 0
            && llGetUnixTime() - gReportRequestedAt >= REPORT_REQUEST_TIMEOUT_SECONDS)
        {
            gPendingReportRequests = [];
            gFailures += 1;
            llOwnerSay("Markov metrics request timed out after "
                + (string)REPORT_REQUEST_TIMEOUT_SECONDS + " seconds.");
        }
    }

    http_response(key request_id, integer status, list metadata, string body)
    {
        if (list_contains_key(gPendingReportRequests, request_id))
        {
            gPendingReportRequests = remove_key(gPendingReportRequests, request_id);
            if (status != 200)
            {
                gFailures += 1;
                owner_say_chunks("Markov metrics request failed: HTTP "
                    + (string)status + " | " + body);
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
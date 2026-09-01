// TiaDE Ollama Team Chatbot for Second Life.
// Public commands on channel 8811: !ai help, !ai say <text>, !ai history.
// Owner-only commands: !ai team <name>, !ai mode local|whisper, !ai auto on|off,
// !ai log <text>, !ai status.

string SERVER_URL = "https://stimky.info";
string TEAM_NAME = "secondlife";
string BOT_NAME = "TiaDE";
integer COMMAND_CHANNEL = 8811;
integer AUTO_REPLY = TRUE;
integer REPLY_MODE = 0; // 0 = public chat, 1 = direct reply to the speaker
integer MAX_CHAT_MESSAGE_LENGTH = 230;

integer gRequestInFlight;
key gLastRequest = NULL_KEY;
string gRequestKind = "";
key gPendingSender = NULL_KEY;
integer gPendingReplyMode;
integer gControlListenHandle;
integer gPublicListenHandle;
string gLastError = "";

string first_word(string input)
{
    integer index = llSubStringIndex(input, " ");
    if (index < 0) return input;
    return llGetSubString(input, 0, index - 1);
}

string rest_of(string input)
{
    integer index = llSubStringIndex(input, " ");
    if (index < 0) return "";
    return llStringTrim(llGetSubString(input, index + 1, -1), STRING_TRIM);
}

string reply_mode_name(integer mode)
{
    if (mode == 1) return "whisper";
    return "local";
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
        llOwnerSay(llGetSubString(text, start, start + MAX_CHAT_MESSAGE_LENGTH - 1));
        start += MAX_CHAT_MESSAGE_LENGTH;
    }
    return 0;
}

integer reply_chunks(string text, key recipient, integer reply_mode)
{
    integer start = 0;
    integer length = llStringLength(text);

    if (length == 0) text = "(empty response)";
    length = llStringLength(text);
    while (start < length)
    {
        string chunk = llGetSubString(text, start, start + MAX_CHAT_MESSAGE_LENGTH - 1);
        if (reply_mode == 1 && recipient != NULL_KEY)
        {
            llRegionSayTo(recipient, 0, chunk);
        }
        else
        {
            llSay(0, chunk);
        }
        start += MAX_CHAT_MESSAGE_LENGTH;
    }
    return 0;
}

string chat_payload(string message)
{
    return llJsonSetValue("{}", ["message"], message);
}

string log_entry(string message, key speaker_id, string speaker_name)
{
    vector position = llGetPos();
    return llList2Json(JSON_OBJECT, [
        "avatar_id", (string)speaker_id,
        "avatar_name", speaker_name,
        "captured_by", llKey2Name(llGetOwner()),
        "message", message,
        "sim_name", llGetRegionName(),
        "timestamp", llGetUnixTime(),
        "x_pos", position.x,
        "y_pos", position.y,
        "z_pos", position.z
    ]);
}

integer begin_request(string kind, string url, list options, string body, key sender)
{
    if (gRequestInFlight)
    {
        gLastError = "A relay request is already in flight.";
        llOwnerSay(gLastError);
        return FALSE;
    }

    gRequestInFlight = TRUE;
    gRequestKind = kind;
    gPendingSender = sender;
    gPendingReplyMode = REPLY_MODE;
    gLastRequest = llHTTPRequest(url, options, body);
    return TRUE;
}

integer send_chat_request(string prompt, key sender_id, string sender_name)
{
    string text = llStringTrim(prompt, STRING_TRIM);
    if (text == "") return FALSE;
    return begin_request(
        "chat",
        SERVER_URL + "/chat/" + llEscapeURL(TEAM_NAME),
        [HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json", HTTP_VERIFY_CERT, TRUE],
        chat_payload(sender_name + ": " + text),
        sender_id
    );
}

integer send_history_request()
{
    return begin_request(
        "history",
        SERVER_URL + "/history/" + llEscapeURL(TEAM_NAME),
        [HTTP_METHOD, "GET", HTTP_VERIFY_CERT, TRUE],
        "",
        NULL_KEY
    );
}

integer send_log_request(string entry, key sender_id, string sender_name)
{
    return begin_request(
        "log",
        SERVER_URL + "/sl_logger",
        [HTTP_METHOD, "POST", HTTP_MIMETYPE, "text/plain", HTTP_VERIFY_CERT, TRUE],
        log_entry(entry, sender_id, sender_name),
        NULL_KEY
    );
}

integer show_help()
{
    owner_say_chunks("Commands: !ai help | !ai say <text> | !ai history | !ai team <name> | !ai mode local|whisper | !ai auto on|off | !ai log <text> | !ai status");
    return 0;
}

integer show_status()
{
    llOwnerSay("Ollama relay: server=" + SERVER_URL + " team=" + TEAM_NAME
        + " reply=" + reply_mode_name(REPLY_MODE)
        + " auto=" + (string)AUTO_REPLY
        + " busy=" + (string)gRequestInFlight);
    if (gLastError != "") llOwnerSay("Last error: " + gLastError);
    return 0;
}

integer is_owner(key avatar_id)
{
    return avatar_id == llGetOwner();
}

integer handle_command(string message, string sender_name, key sender_id)
{
    string command = llToLower(first_word(message));
    string argument = rest_of(message);

    if (command == "" || command == "help" || command == "?")
    {
        show_help();
        return 0;
    }
    if (command == "say")
    {
        if (!send_chat_request(argument, sender_id, sender_name))
        {
            if (argument == "") llOwnerSay("Usage: !ai say <message>");
        }
        return 0;
    }
    if (command == "history")
    {
        send_history_request();
        return 0;
    }
    if (!is_owner(sender_id))
    {
        llOwnerSay("That command is owner-only.");
        return 0;
    }
    if (command == "team")
    {
        if (argument == "") llOwnerSay("Current team: " + TEAM_NAME);
        else
        {
            TEAM_NAME = argument;
            llOwnerSay("Team set to " + TEAM_NAME);
        }
        return 0;
    }
    if (command == "mode")
    {
        if (llToLower(argument) == "whisper") REPLY_MODE = 1;
        else if (llToLower(argument) == "local") REPLY_MODE = 0;
        else
        {
            llOwnerSay("Usage: !ai mode local|whisper");
            return 0;
        }
        llOwnerSay("Reply mode set to " + reply_mode_name(REPLY_MODE) + ".");
        return 0;
    }
    if (command == "auto")
    {
        if (llToLower(argument) == "on") AUTO_REPLY = TRUE;
        else if (llToLower(argument) == "off") AUTO_REPLY = FALSE;
        else
        {
            llOwnerSay("Usage: !ai auto on|off");
            return 0;
        }
        llOwnerSay("Auto-reply " + (string)AUTO_REPLY + ".");
        return 0;
    }
    if (command == "log")
    {
        if (argument == "") llOwnerSay("Usage: !ai log <text>");
        else send_log_request(argument, sender_id, sender_name);
        return 0;
    }
    if (command == "status")
    {
        show_status();
        return 0;
    }
    llOwnerSay("Unknown command. Use !ai help.");
    return 0;
}

integer handle_public_message(string message, string sender_name, key sender_id)
{
    if (message == "" || sender_id == llGetOwner() || sender_id == llGetKey()) return 0;
    if (llGetSubString(message, 0, 0) == "/" || llGetSubString(message, 0, 2) == "!ai") return 0;
    send_chat_request(message, sender_id, sender_name);
    return 0;
}

default
{
    state_entry()
    {
        gControlListenHandle = llListen(COMMAND_CHANNEL, "", NULL_KEY, "");
        gPublicListenHandle = llListen(0, "", NULL_KEY, "");
        llOwnerSay("Ollama team chatbot ready. Use !ai help on channel " + (string)COMMAND_CHANNEL + ".");
    }

    listen(integer channel, string name, key id, string message)
    {
        if (channel == COMMAND_CHANNEL)
        {
            if (llToLower(llGetSubString(message, 0, 2)) != "!ai") return;
            handle_command(rest_of(message), name, id);
            return;
        }
        if (channel == 0 && AUTO_REPLY)
        {
            handle_public_message(message, name, id);
        }
    }

    changed(integer change)
    {
        if (change & CHANGED_OWNER) llResetScript();
    }

    http_response(key request_id, integer status, list metadata, string body)
    {
        string response_text;
        if (request_id != gLastRequest) return;
        gRequestInFlight = FALSE;

        if (status != 200)
        {
            response_text = llJsonGetValue(body, ["error"]);
            if (response_text == JSON_INVALID) response_text = body;
            gLastError = "HTTP " + (string)status + ": " + response_text;
            owner_say_chunks("Relay request failed: " + gLastError);
            return;
        }
        if (gRequestKind == "history")
        {
            response_text = llJsonGetValue(body, ["history"]);
            if (response_text == JSON_INVALID) response_text = "No history was returned.";
            owner_say_chunks("History for " + TEAM_NAME + ":\n" + response_text);
            return;
        }
        if (gRequestKind == "log")
        {
            llOwnerSay("Log entry accepted by relay.");
            return;
        }

        response_text = llJsonGetValue(body, ["response"]);
        if (response_text == JSON_INVALID) response_text = "The relay did not return a usable response.";
        reply_chunks(BOT_NAME + ": " + response_text, gPendingSender, gPendingReplyMode);
    }
}
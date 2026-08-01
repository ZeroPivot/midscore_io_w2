// TiaDE Ollama Team Chatbot for Second Life
//
// Features:
// - Sends chat prompts to the relay backend at /chat/:team
// - Supports a configurable team name so conversations are grouped
// - Responds in local/public chat or by whispering to the speaker
// - Supports direct commands via a dedicated listen channel
// - Supports history lookup via /history/:team
// - Supports logging to /sl_logger
//
// Setup:
// 1. Change SERVER_URL to your relay host (for example http://your-host:8080)
// 2. Change TEAM_NAME to your preferred team slug
// 3. Drop this script into a prim/object in Second Life
// 4. Say on channel 8811: !ai help
//
// Example commands:
//   !ai help
//   !ai team myteam
//   !ai mode local
//   !ai mode whisper
//   !ai say hello there
//   !ai history
//   !ai log test entry
//   !ai status

string SERVER_URL = "http://127.0.0.1:8080";
string TEAM_NAME = "sl_team";
string BOT_NAME = "TiaDE";
integer COMMAND_CHANNEL = 8811;
integer AUTO_REPLY = TRUE;
integer REPLY_MODE = 0; // 0 = public local chat, 1 = whisper to speaker

integer REQUEST_IN_FLIGHT = FALSE;
key LAST_REQUEST = NULL_KEY;
string PENDING_TEXT = "";
key PENDING_SENDER = NULL_KEY;
string PENDING_SENDER_NAME = "";
integer PENDING_REPLY_MODE = 0;
integer PENDING_PUBLIC = 0;
string LAST_ERROR = "";

string firstWord(string input)
{
    integer idx = llSubStringIndex(input, " ");
    if (idx < 0) return input;
    return llGetSubString(input, 0, idx - 1);
}

string restOf(string input)
{
    integer idx = llSubStringIndex(input, " ");
    if (idx < 0) return "";
    return llGetSubString(input, idx + 1, -1);
}

string speakText(string text)
{
    if (REPLY_MODE == 1) {
        llOwnerSay(text);
        return text;
    }
    llSay(0, text);
    return text;
}

string speakToAvatar(string text, key avatar_id)
{
    if (REPLY_MODE == 1) {
        llRegionSayTo(avatar_id, 0, text);
    }
    else {
        llSay(0, text);
    }
    return text;
}

string stripLeadingSpace(string input)
{
    integer len = llStringLength(input);
    while (len > 0 && llGetSubString(input, 0, 0) == " ") {
        input = llGetSubString(input, 1, -1);
        len = llStringLength(input);
    }
    return input;
}

string buildChatPayload(string message)
{
    string payload = "{}";
    payload = llJsonSetValue(payload, ["message"], message);
    return payload;
}

sendChatRequest(string prompt, key sender_id, string sender_name, integer public_reply)
{
    if (REQUEST_IN_FLIGHT) {
        LAST_ERROR = "Busy; previous request still in flight";
        if (public_reply) {
            llOwnerSay("Busy; previous request still in flight.");
        }
        return;
    }

    string url = SERVER_URL + "/chat/" + llEscapeURL(TEAM_NAME);
    string payload = buildChatPayload(prompt);

    REQUEST_IN_FLIGHT = TRUE;
    LAST_REQUEST = llHTTPRequest(url, [HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json"], payload);
    PENDING_TEXT = prompt;
    PENDING_SENDER = sender_id;
    PENDING_SENDER_NAME = sender_name;
    PENDING_REPLY_MODE = REPLY_MODE;
    PENDING_PUBLIC = public_reply;
}

sendHistoryRequest()
{
    if (REQUEST_IN_FLIGHT) {
        LAST_ERROR = "Busy; previous request still in flight";
        llOwnerSay("Busy; previous request still in flight.");
        return;
    }

    string url = SERVER_URL + "/history/" + llEscapeURL(TEAM_NAME);
    REQUEST_IN_FLIGHT = TRUE;
    LAST_REQUEST = llHTTPRequest(url, [HTTP_METHOD, "GET"], "");
    PENDING_TEXT = "__history__";
    PENDING_SENDER = NULL_KEY;
    PENDING_SENDER_NAME = "";
    PENDING_REPLY_MODE = 0;
    PENDING_PUBLIC = 1;
}

sendLogRequest(string entry)
{
    if (REQUEST_IN_FLIGHT) {
        LAST_ERROR = "Busy; previous request still in flight";
        llOwnerSay("Busy; previous request still in flight.");
        return;
    }

    string url = SERVER_URL + "/sl_logger";
    REQUEST_IN_FLIGHT = TRUE;
    LAST_REQUEST = llHTTPRequest(url, [HTTP_METHOD, "POST", HTTP_MIMETYPE, "text/plain"], entry);
    PENDING_TEXT = "__log__";
    PENDING_SENDER = NULL_KEY;
    PENDING_SENDER_NAME = "";
    PENDING_REPLY_MODE = 0;
    PENDING_PUBLIC = 1;
}

showHelp()
{
    string help = "Ollama relay commands: !ai help | !ai team <name> | !ai mode local | !ai mode whisper | !ai say <text> | !ai history | !ai log <text> | !ai status";
    llOwnerSay(help);
}

showStatus()
{
    string status = "Ollama relay: server=" + SERVER_URL + " team=" + TEAM_NAME + " reply=" + (REPLY_MODE == 0 ? "local" : "whisper") + " auto_reply=" + (AUTO_REPLY ? "on" : "off");
    llOwnerSay(status);
}

handleCommand(string message, string sender_name, key sender_id)
{
    string cmd = llToLower(firstWord(message));
    string arg = stripLeadingSpace(restOf(message));

    if (cmd == "help" || cmd == "?" || message == "!ai") {
        showHelp();
        return;
    }

    if (cmd == "team") {
        if (llStringLength(arg) > 0) {
            TEAM_NAME = arg;
            llOwnerSay("Team set to " + TEAM_NAME);
        }
        else {
            llOwnerSay("Current team: " + TEAM_NAME);
        }
        return;
    }

    if (cmd == "mode") {
        if (llToLower(arg) == "whisper") {
            REPLY_MODE = 1;
            llOwnerSay("Reply mode set to whisper.");
        }
        else {
            REPLY_MODE = 0;
            llOwnerSay("Reply mode set to local/public.");
        }
        return;
    }

    if (cmd == "say") {
        if (llStringLength(arg) > 0) {
            sendChatRequest(arg, sender_id, sender_name, 1);
        }
        else {
            llOwnerSay("Usage: !ai say <message>");
        }
        return;
    }

    if (cmd == "history") {
        sendHistoryRequest();
        return;
    }

    if (cmd == "log") {
        if (llStringLength(arg) > 0) {
            sendLogRequest(arg);
        }
        else {
            llOwnerSay("Usage: !ai log <text>");
        }
        return;
    }

    if (cmd == "status") {
        showStatus();
        return;
    }

    if (cmd == "auto") {
        if (llToLower(arg) == "off") {
            AUTO_REPLY = FALSE;
            llOwnerSay("Auto-reply disabled.");
        }
        else {
            AUTO_REPLY = TRUE;
            llOwnerSay("Auto-reply enabled.");
        }
        return;
    }

    llOwnerSay("Unknown command. Try !ai help.");
}

handleUserMessage(string message, string sender_name, key sender_id)
{
    if (llStringLength(message) < 1) return;
    if (llGetSubString(message, 0, 0) == "/") return;
    if (message == "!ai") return;
    if (llGetSubString(message, 0, 2) == "!ai") return;
    if (sender_id == llGetOwner()) return;

    string prompt = sender_name + ": " + message;
    sendChatRequest(prompt, sender_id, sender_name, 1);
}

default
{
    state_entry()
    {
        llListen(COMMAND_CHANNEL, "", "", "");
        llListen(0, "", "", "");
        llOwnerSay("Ollama team chatbot ready. Channel " + (string)COMMAND_CHANNEL + " | team " + TEAM_NAME + " | use !ai help");
    }

    listen(integer channel, string name, key id, string message)
    {
        if (channel == COMMAND_CHANNEL) {
            if (llGetSubString(message, 0, 2) != "!ai") return;
            handleCommand(llGetSubString(message, 4, -1), name, id);
            return;
        }

        if (channel == 0 && AUTO_REPLY) {
            handleUserMessage(message, name, id);
        }
    }

    touch_start(integer num_detected)
    {
        llOwnerSay("Tap me to use the chatbot. Commands go on channel " + (string)COMMAND_CHANNEL + " with !ai help.");
    }

    http_response(key request_id, integer status, list metadata, string body)
    {
        if (request_id != LAST_REQUEST) return;

        REQUEST_IN_FLIGHT = FALSE;

        if (status != 200) {
            LAST_ERROR = "HTTP status " + (string)status + " body=" + body;
            llOwnerSay("Relay request failed: " + LAST_ERROR);
            return;
        }

        if (PENDING_TEXT == "__history__") {
            string history = llJsonGetValue(body, ["history"]);
            if (history == JSON_INVALID) {
                llOwnerSay("No history was returned.");
            }
            else {
                llOwnerSay("History for team " + TEAM_NAME + ":\n" + history);
            }
            return;
        }

        if (PENDING_TEXT == "__log__") {
            llOwnerSay("Log entry accepted by relay.");
            return;
        }

        string response_text = llJsonGetValue(body, ["response"]);
        if (response_text == JSON_INVALID) {
            response_text = llJsonGetValue(body, ["error"]);
        }
        if (response_text == JSON_INVALID) {
            response_text = "The relay did not return a usable response.";
        }

        string reply = BOT_NAME + ": " + response_text;
        if (PENDING_SENDER != NULL_KEY && PENDING_REPLY_MODE == 1) {
            llRegionSayTo(PENDING_SENDER, 0, reply);
        }
        else {
            llSay(0, reply);
        }
    }
}

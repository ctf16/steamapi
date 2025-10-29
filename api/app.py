from flask import Flask, jsonify, request
import requests
import json

app = Flask(__name__)

@app.route("/api")
def home():
    return "Welcome to Calvin's Steam user API.\nCurl the following URL, replacing STEAMID with the desired ID found at steamcommunity.com/id/STEAMID and APIKEY with your Steam Web API key.\n    http://localhost:8080/api/steamuser?steamid=STEAMID\n    https://localhost/api/steamuser?steamid=STEAMID\nTo pass your Steam Web API key with your request, include an HTTP header with the curl flag '-H' and the header field 'X-API-Key'\n"

@app.route("/api/steamuser", methods=["GET"])
def getuser():
    steamid = request.args.get("steamid")
    apikey = request.headers.get("X-API-Key")

    if not steamid:
        return jsonify({"query error": "Missing steamuser=STEAMID parameter"}), 400
    if not apikey:
        return jsonify({"query error": "Missing X-API-Key header"}), 400
    
    try:
        vanity_url = f'https://api.steampowered.com/ISteamUser/ResolveVanityURL/v1/?key={apikey}&vanityurl={steamid}'
        vanity = requests.get(vanity_url).json()

        if "steamid" not in vanity.get("response", {}):
            return jsonify({"user error": f"Could not find user based on their vanity URL {steamid}"})

        steamid64 = vanity["response"]["steamid"]
        api_url = f'https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key={apikey}&steamids={steamid64}'
        response = requests.get(api_url).json()
        player = response["response"]["players"][0]

        # status map based on https://developer.valvesoftware.com/wiki/Steam_Web_API#GetPlayerSummaries_(v0002)
        status = {
            0: "Offline",
            1: "Online",
            2: "Busy",
            3: "Away",
            4: "Snooze",
            5: "Looking to trade",
            6: "Looking to play"
        }

        visibility = player.get("communityvisibilitystate", "Could not fetch user's visibility state.")
        result = {}
        if visibility == 1:
            # not visible to you (private, friends only))
            result = {
                "Display Name": player.get("personaname"),
                "SteamID64": player.get("steamid"),
                "Full Avatar URL": player.get("avatarfull"),
                "Status": status.get(player.get("personastate"), "Unknown status.")
            }
        else: #visibility == 3
            result = {
                "Display Name": player.get("personaname"),
                "Name": player.get("realname", "Player does not have their real name set."),
                "SteamID64": player.get("steamid"),
                "Vanity URL": player.get("profileurl"),
                "Country": player.get("loccountrycode", "User does not display their country."),
                "User Status": status.get(player.get("personastate"), "Unknown status."),
                "Current Game": player.get("gameextrainfo", "User is not currently in game.")
            }
    
        return jsonify(result)

    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

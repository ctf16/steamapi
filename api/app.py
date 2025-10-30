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
        steamid64 = resolve_vanity(apikey, steamid) 
        api_url = f'https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key={apikey}&steamids={steamid64}'
        player = requests.get(api_url).json()["response"]["players"][0]
    
        return jsonify(player)

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/api/games", methods=["GET"])
def getgames():
    steamid = request.args.get("steamid")
    apikey = request.headers.get("X-API-Key")

    if not steamid:
        return jsonify({"query error": "Missing steamuser=STEAMID parameter"}), 400
    if not apikey:
        return jsonify({"query error": "Missing X-API-Key header"}), 400

    try:
        steamid64 = resolve_vanity(apikey, steamid)
        api_url = f'https://api.steampowered.com/IPlayerService/GetOwnedGames/v0001/?key={apikey}&steamid={steamid64}&format=json&include_appinfo=true'
        ownedgames = requests.get(api_url).json()["response"]

        return jsonify(ownedgames)
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500






# HELPERS
def resolve_vanity(api_key: str, vanity_url: str) -> str | None:
    vurl = f'https://api.steampowered.com/ISteamUser/ResolveVanityURL/v1/?key={api_key}&vanityurl={vanity_url}&format=json'
    vanity = requests.get(vurl).json()

    if "steamid" not in vanity.get("response", {}):
        print(f"Could not find user based on their vanity URL {vanity_url}")
        return None

    id64 = vanity["response"]["steamid"]
    return id64



if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

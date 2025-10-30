# Basic Python app that implements a client that allows for repeated querying of the API

import requests
import sys
import time

status = {
    0: "Offline",
    1: "Online",
    2: "Busy",
    3: "Away",
    4: "Snooze",
    5: "Looking to trade",
    6: "Looking to play"
}


# ----------------------------------
# ---------- MENU ACTIONS ----------
# ----------------------------------
def action_summary(api_key:str):
    vanity = input("\nEnter a Steam vanity url (steamcommunity.com/id/VANITYURL): ").strip()
    akh = {'X-API-Key': api_key}

    purl = f'https://localhost/api/steamuser?steamid={vanity}'
    player = requests.get(purl, headers=akh, verify=False).json()
    if not player:
        print("No player data found.")
        return

    vis = player.get("communityvisibilitystate", "Could not fetch user's visibility state.")
    result = {}
    if vis == 1:
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

    print("\nPlayer Summary:")
    print("----------------")
    for meta, data in result.items():
        print(f"{meta}: {data}")



def action_top10(api_key: str):
    vanity = input("\nEnter a Steam vanity url (steamcommunity.com/id/VANITYURL): ").strip()
    akh = {'X-API-Key': api_key}

    purl = f'https://localhost/api/steamuser?steamid={vanity}'
    player = requests.get(purl, headers=akh, verify=False).json()

    gurl = f'https://localhost/api/games?steamid={vanity}'
    print(f"Querying {gurl}...")
    games = requests.get(gurl, headers=akh, verify=False).json()
    ign = player.get("personaname")

    sortedgames = sorted(games["games"], key=lambda g: g.get("playtime_forever", 0), reverse=True)[:10]
    gamecount = games["game_count"]

    print(f"\n{ign}'s Top 10 Most Played Games:")
    print("----------------")
    i = 1
    for game in sortedgames:
        hr = game["playtime_forever"] / 60
        print(f"[#{i}] {game['name']}: {hr:.1f} hrs")
        i += 1
    print("----------------")
    print(f"{ign} owns {gamecount} games total (excluding F2P).")


def action_allgames(api_key: str):
    vanity = input("\nEnter a Steam vanity url (steamcommunity.com/id/VANITYURL): ").strip()
    akh = {'X-API-Key': api_key}

    purl = f'https://localhost/api/steamuser?steamid={vanity}'
    player = requests.get(purl, headers=akh, verify=False).json()

    gurl = f'https://localhost/api/games?steamid={vanity}'
    games = requests.get(gurl, headers=akh, verify=False).json()
    ign = player.get("personaname") 

    sortedgames = sorted(games["games"], key=lambda g: g.get("playtime_forever", 0), reverse=True)
    gamecount = games["game_count"]

    print(f"\n{ign}'s Owned Games:")
    print("----------------------")
    i = 1
    for game in sortedgames:
        hr = game["playtime_forever"] / 60
        print(f"[#{i}] {game['name']}: {hr:.1f} hrs")
        i += 1
    print("----------------------")
    print(f"{ign} owns {gamecount} games total (excluding F2P).")



# -------------------------------
# ---------- MAIN MENU ----------
# -------------------------------
def menu(api_key: str):
    actions = {
        "1": ("Profile Summary", action_summary),
        "2": ("Top 10 Games", action_top10),
        "3": ("All Games", action_allgames),
        "0": ("Exit", None),
        "X": ("Change API key", None)
    }

    apik = api_key
    while True:
        print("\n----- Steam API Client -----")
        for key, (label,_) in actions.items():
            print(f"[{key}] {label}")

        choice = input("\nChoose an option: ").strip()

        if choice == "0":
            print("\nExiting...")
            time.sleep(0.5)
            sys.exit(0)
        elif choice == "X":
            apik = input("\nEnter a new API key: ").strip()
            while not apik:
                print("Can't proceed without a valid API key.")
                apik = input("\nEnter a new API key: ").strip()
        elif choice in actions:
            _, func = actions[choice]
            func(apik)
        else:
            print("Invalid choice. Enter a new request.")



def main():
    print("Welcome to Calvin's Steam API client!\n")
    api_key = input("Before proceeding, please enter your Steam Web API key: ").strip()

    while not api_key:
        print("Can not proceed without an API key")
        api_key = input("Please enter a Steam Web API key: ").strip()

    print("\nRemembering API key for client session...")
    menu(api_key)

if __name__ == "__main__":
    main()
    



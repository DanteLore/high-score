# high-score
High Score as a Service for AWS

This project contains a lambda function, dynamo DB table and example javascript to save and load high scores for an online game.

Who knows who might find it useful.

Features:

* Store scores via REST call
* Recall the top 10 scores to display a leaderboard
* Supports multiple games (by name)
* Abuse and profanity filter
* Removal of HTML, special characters etc
* Username length limits

Run `./build.sh` to deploy.

If you're excited to see the game in action, head to [https://dantelore.com/highscore/]
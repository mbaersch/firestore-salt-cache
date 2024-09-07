# Firestore Salt Cache

**Custom Variable Template for server-side Google Tag Manager**

Manage a random salt cache with variable lifespan using Firestore. Creates and updates salt value automatically. Uses Template Data Storage to reduce Firestore requests.

![Template Status](https://img.shields.io/badge/Community%20Template%20Gallery%20Status-submitted-orange) ![Repo Size](https://img.shields.io/github/repo-size/mbaersch/firestore-salt-cache) ![License](https://img.shields.io/github/license/mbaersch/firestore-salt-cache)

**Note**: Create a native Firestore database first and add an empty document for this template. This document will contain the random value and its timestamp.  

## Usage 
Add this template to your container and create a new variable with it.

Enter a path to an already existing document in the first field *Salt Cache Firestore Document*. To use a Firestore database from a different project, enter the project id below. 

### Options
You can define the **Salt String Length** value that is used. Enter any value between 10 and 64.

Select an option for **Salt Expiration**. You can either create a salt value that never expires (even if this only might make sense in edge cases), expiration at midnight or a lifespan in hours. If you pick *Expires At Midnight*, enter a *UTC Offset* in hours, so the tag knows at which time a new value has to be generated.  

Whenever the variable value is accessed, the existing value will be returned if not expired. If the timestamp indicates that a new value is needed, the template generates a new random value, stores it in Firestore and returns the new value. 

In order to avoid querying Firestore everytime the salt is accessed, the template uses a cache.  
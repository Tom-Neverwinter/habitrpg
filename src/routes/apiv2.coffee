###
---------- /api/v2 API ------------
see https://github.com/wordnik/swagger-node-express
Every url added to router is prefaced by /api/v2
Note: Many user-route ops exist in habitrpg-shard/script/index.coffee#user.ops, so that they can (1) be called both
client and server.
v1 user. Requires x-api-user (user id) and x-api-key (api key) headers, Test with:
$ mocha test/user.mocha.coffee
###

user = require("../controllers/user")
groups = require("../controllers/groups")
auth = require("../controllers/auth")
admin = require("../controllers/admin")
challenges = require("../controllers/challenges")
dataexport = require("../controllers/dataexport")
nconf = require("nconf")
middleware = require("../middleware")
cron = user.cron
_ = require('lodash')
content = require('habitrpg-shared').content


module.exports = (swagger, v2, errorHandler) ->
  [path,body,query] = [swagger.pathParam, swagger.bodyParam, swagger.queryParam]

  swagger.setAppHandler(v2);
  swagger.setErrorHandler("next");
  swagger.configureSwaggerPaths("", "/api-docs", "")

  api =

    '/status':
      spec:
        description: "Returns the status of the server (up or down)"
      action: (req, res) ->
        test()
        res.json status: "up"

    '/content':
      spec:
        description: "Get all available content objects. This is essential, since Habit often depends on item keys (eg, when purchasing a weapon)."
      action: user.getContent


    "/export/history":
      spec:
        description: "Export user history"
        method: 'GET'
      middleware: auth.auth
      action: dataexport.history #[todo] encode data output options in the data controller and use these to build routes

    # ---------------------------------
    # User
    # ---------------------------------

    # Scoring

    "/user/tasks/{id}/{direction}":
      spec:
        description: "Simple scoring of a task"
        params: [
          path("id", "ID of the task to score. If this task doesn't exist, a task will be created automatically", "string")
          path("direction", "Either 'up' or 'down'", "string")
        ]
        method: 'POST'
      action: user.score

    # Tasks
    "/user/tasks":
      spec:
        description: "Get all user's tasks"
      action: user.getTasks

    "/user/tasks/{id}":
      spec:
        description: "Get an individual task"
        params: [
          path("id", "Task ID", "string")
        ]
      action: user.getTask

    "/user/tasks/{id}":
      spec:
        description: "Update a user's task"
        method: 'PUT'
        params: [
          path("id", "Task ID", "string")
          body("","Send up the whole task","object")
        ]
      action: user.updateTask

    "/user/tasks/{id}":
      spec:
        description: "Delete a task"
        method: 'DELETE'
        params: [ path("id", "Task ID", "string") ]
      action: user.deleteTask

    "/user/tasks":
      spec:
        description: "Create a task"
        method: 'POST'
        params: [ body("","Send up the whole task","object") ]
      action: user.addTask


    "/user/tasks/{id}/sort":
      spec:
        method: 'POST'
        description: 'Sort tasks'
        params: [
          path("id", "Task ID", "string")
          query("from","Index where you're sorting from (0-based)","integer")
          query("to","Index where you're sorting to (0-based)","integer")
        ]
      action: user.sortTask

    "/user/tasks/clear-completed":
      spec:
        method: 'POST'
        description: "Clears competed To-Dos (needed periodically for performance."
      action: user.clearCompleted


    "/user/tasks/{id}/unlink":
      spec:
        method: 'POST'
        description: 'Unlink a task from its challenge'
        # TODO query params?
        params: [path("id", "Task ID", "string")]
      middleware: auth.auth ## removing cron since they may want to remove task first
      action: challenges.unlink


    # Inventory
    "/user/inventory/buy/{key}":
      spec:
        method: 'POST'
        description: "Buy a gear piece and equip it automatically"
        params:[
          path 'key',"The key of the item to buy (call /content route for available keys)",'string', _.keys(content.gear.flat)
          #TODO embed keys
        ]
      action: user.buy

    "/user/inventory/sell/{type}/{key}":
      spec:
        method: 'POST'
        description: "Sell inventory items back to Alexander"
        params: [
          #TODO verify these are the correct types
          path('type',"The type of object you're selling back.",'string',['gear','eggs','hatchingPotions','food'])
          path('key',"The object key you're selling back (call /content route for available keys)",'string')
        ]
      action: user.sell

    "/user/inventory/purchase/{type}/{key}":
      spec:
        method: 'POST'
        description: "Purchase a gem-purchaseable item from Alexander"
        params:[
          path('type',"The type of object you're purchasing.",'string',['gear','eggs','hatchingPotions','food'])
          path('key',"The object key you're purchasing (call /content route for available keys)",'string')
        ]
      action: user.purchase


    "/user/inventory/feed/{pet}/{food}":
      spec:
        method: 'POST'
        description: "Feed your pet some food"
        params: [
          path 'pet',"The key of the pet you're feeding",'string'#,_.keys(content.pets))
          path 'food',"The key of the food to feed your pet",'string',_.keys(content.food)
        ]
      action: user.feed

    "/user/inventory/equip/{type}/{key}":
      spec:
        method: 'POST'
        description: "Equip an item (either pets, mounts, or gear)"
        params: [
          path 'type',"Type to equip",'string',['pets','mounts','gear']
          path 'key',"The object key you're equipping (call /content route for available keys)",'string'
        ]
      action: user.equip

    "/user/inventory/hatch/{egg}/{hatchingPotion}":
      spec:
        method: 'POST'
        description: "Pour a hatching potion on an egg"
        params: [
          path 'egg',"The egg key to hatch",'string',_.keys(content.eggs)
          path 'hatchingPotion',"The hatching potion to pour",'string',_.keys(content.hatchingPotions)
        ]
      action: user.hatch


    # User
    "/user:GET":
      spec:
        path: '/user'
        description: "Get the full user object"
      action: user.getUser

    "/user:PUT":
      spec:
        path: '/user'
        method: 'PUT'
        description: "Update the user object (only certain attributes are supported)"
        params: [
          body '','The user object','object'
        ]
      action: user.update

    "/user:DELETE":
      spec:
        path: '/user'
        method: 'DELETE'
        description: "Delete a user object entirely, USE WITH CAUTION!"
      middleware: auth.auth
      action: user["delete"]

    "/user/revive":
      spec:
        method: 'POST'
        description: "Revive your dead user"
      action: user.revive

    "/user/reroll":
      spec:
        method: 'POST'
        description: 'Drink the Fortify Potion (Note, it used to be called re-roll)'
      action: user.reroll

    "/user/reset":
      spec:
        method: 'POST'
        description: "Completely reset your account"
      action: user.reset

    "/user/sleep":
      spec:
        method: 'POST'
        description: "Toggle whether you're resting in the inn"
      action: user.sleep

    "/user/rebirth":
      spec:
        method: 'POST'
        description: "Rebirth your avatar"
      action: user.rebirth

    "/user/class/change":
      spec:
        method: 'POST'
        description: "Either remove your avatar's class, or change it to something new"
        params: [
          query 'class',"The key of the class to change to. If not provided, user's class is removed.",'string',['warrior','healer','rogue','wizard','']
        ]
      action: user.changeClass

    "/user/class/allocate":
      spec:
        method: 'POST'
        description: "Allocate one point towards an attribute"
        params: [
          query 'stat','The stat to allocate towards','string'
        ]
      action:user.allocate

    "/user/class/cast/{spell}":
      spec:
        method: 'POST'
        description: "Cast a spell"
        #TODO finish
      action: user.cast

    "/user/unlock":
      spec:
        method: 'POST'
        description: "Unlock a certain gem-purchaseable path (or multiple paths)"
        params: [
          query 'path',"The path to unlock, such as hair.green or shirts.red,shirts.blue",'string'
        ]
      action: user.unlock

    "/user/buy-gems":
      spec: method: 'POST', description: "Do not use this route!"
      middleware: auth.auth
      action:user.buyGems

    "/user/buy-gems/paypal-ipn":
      spec: method: 'POST', description: "Don't use this route!"
      action: user.buyGemsPaypalIPN

    "/user/batch-update":
      spec:
        method: 'POST'
        description: "This is an advanced route which is useful for apps which might for example need offline support. You can send a whole batch of user-based operations, which allows you to queue them up offline and send them all at once. The format is {op:'nameOfOperation',params:{},body:{},query:{}}"
        params:[
          body '','The array of batch-operations to perform','object'
        ]
      middleware: [middleware.forceRefresh, auth.auth, cron]
      action: user.batchUpdate

    # Tags
    "/user/tags":
      spec:
        method: 'POST'
        description: 'Create a new tag'
        params: [
          #TODO document
          body '','New tag','object'
        ]
      action: user.addTag

    "/user/tags/{id}:PUT":
      spec:
        path: 'user/tags/{id}'
        method: 'PUT'
        description: "Edit a tag"
        params: [
          path 'id','The id of the tag to edit','string'
          body '','Tag edits','object'
        ]
      action: user.updateTag

    "/user/tags/{id}:DELETE":
      spec:
        path: 'user/tags/{id}'
        method: 'DELETE'
        description: 'Delete a tag'
        params: [
          path 'id','Id of tag to delete','string'
        ]
      action: user.deleteTag

    # ---------------------------------
    # Groups
    # ---------------------------------
    "/groups:GET":
      spec: path: '/groups'
      middleware: auth.auth
      action: groups.list

    "/groups:POST":
      spec: path: '/groups', method: 'POST'
      middleware: auth.auth
      action: groups.create

    "/groups/{gid}:GET":
      spec: path: '/groups/{gid}'
      middleware: auth.auth
      action: groups.get

    "/groups/{gid}":
      spec: path: '/groups/{gid}', method: 'PUT'
      middleware: [auth.auth, groups.attachGroup]
      action: groups.update

    "/groups/{gid}/join":
      spec: method: 'POST'
      middleware: [auth.auth, groups.attachGroup]
      action: groups.join

    "/groups/{gid}/leave":
      spec: method: 'POST'
      middleware: [auth.auth, groups.attachGroup]
      action: groups.leave

    "/groups/{gid}/invite":
      spec: method: 'POST'
      middleware: [auth.auth, groups.attachGroup]
      action:groups.invite

    "/groups/{gid}/removeMember":
      spec:method: 'POST'
      middleware: [auth.auth, groups.attachGroup]
      action:groups.removeMember

    "/groups/{gid}/questAccept":
      spec:
        method: 'POST'
        params: [
          query 'key',"optional. if provided, trigger new invite, if not, accept existing invite",'string'
        ]
      middleware: [auth.auth, groups.attachGroup]
      action:groups.questAccept

    "/groups/{gid}/questReject":
      spec: method: 'POST'
      middleware: [auth.auth, groups.attachGroup]
      action: groups.questReject

    "/groups/{gid}/questAbort":
      spec: method: 'POST'
      middleware: [auth.auth, groups.attachGroup]
      action: groups.questAbort

    #TODO GET  /groups/:gid/chat
    #TODO PUT  /groups/:gid/chat/:messageId

    "/groups/{gid}/chat":
      spec: method: 'POST'
      middleware: [auth.auth, groups.attachGroup]
      action: groups.postChat

    "/groups/{gid}/chat/{messageId}":
      spec: method: 'DELETE'
      middleware: [auth.auth, groups.attachGroup]
      action: groups.deleteChatMessage

    # ---------------------------------
    # Members
    # ---------------------------------
    "/members/{uid}":
      spec:{}
      action: groups.getMember

    # ---------------------------------
    # Admin
    # ---------------------------------
    "/admin/members":
      spec: {}
      middleware:[auth.auth, admin.ensureAdmin]
      action: admin.listMembers

    "/admin/members/{uid}":
      spec: {}
      middleware: [auth.auth, admin.ensureAdmin]
      action: admin.getMember

    "/admin/members/{uid}":
      spec: method: 'POST'
      middleware: [auth.auth, admin.ensureAdmin]
      action: admin.updateMember


    # ---------------------------------
    # Challenges
    # ---------------------------------

    # Note: while challenges belong to groups, and would therefore make sense as a nested resource
    # (eg /groups/:gid/challenges/:cid), they will also be referenced by users from the "challenges" tab
    # without knowing which group they belong to. So to prevent unecessary lookups, we have them as a top-level resource
    "/challenges:GET":
      spec: path: '/challenges'
      middleware: [auth.auth]
      action: challenges.list

    "/challenges:POST":
      spec: path: '/challenges', method: 'POST'
      middleware: [auth.auth]
      action: challenges.create

    "/challenges/{cid}:GET":
      spec: {}
      action: challenges.get

    "/challenges/{cid}:POST":
      spec: path: '/challenges/{cid}', method: 'POST'
      middleware: [auth.auth]
      action: challenges.update

    "/challenges/{cid}:DELETE":
      spec: path: '/challenges/{cid}', method: 'DELETE'
      middleware: [auth.auth]
      action: challenges["delete"]

    "/challenges/{cid}/close":
      spec: method: 'POST'
      middleware: [auth.auth]
      action: challenges.selectWinner

    "/challenges/{cid}/join":
      spec: method: 'POST'
      middleware: [auth.auth]
      action: challenges.join

    "/challenges/{cid}/leave":
      spec: method: 'POST'
      middleware: [auth.auth]
      action: challenges.leave

    "/challenges/{cid}/member/{uid}":
      spec: {}
      middleware: [auth.auth]
      action: challenges.getMember


  if nconf.get("NODE_ENV") is "development"
    api["/user/addTenGems"] =
      spec: method:'POST'
      action: user.addTenGems

  _.each api, (route, path) ->
    ## Spec format is:
    #    spec:
    #      path: "/pet/{petId}"
    #      description: "Operations about pets"
    #      notes: "Returns a pet based on ID"
    #      summary: "Find pet by ID"
    #      method: "GET"
    #      params: [path("petId", "ID of pet that needs to be fetched", "string")]
    #      type: "Pet"
    #      errorResponses: [swagger.errors.invalid("id"), swagger.errors.notFound("pet")]
    #      nickname: "getPetById"

    route.spec.description ?= ''
    _.defaults route.spec,
      path: path
      nickname: path
      notes: route.spec.description
      summary: route.spec.description
      params: []
      #type: 'Pet'
      errorResponses: []
      method: 'GET'
      middleware: if path.indexOf('/user') is 0 then [auth.auth, cron] else []
    swagger["add#{route.spec.method}"](route);true


  swagger.configure(nconf.get('BASE_URL'), "2")
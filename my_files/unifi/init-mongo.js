db.getSiblingDB("admin").createUser({
  user: "unifi", pwd: "unifipass",
  roles: [{role: "root", db: "admin"}]
});

db.getSiblingDB("unifi").createUser({
  user: "unifi", pwd: "unifipass",
  roles: [{role: "dbOwner", db: "unifi"}]
});

db.getSiblingDB("unifi_stat").createUser({
  user: "unifi", pwd: "unifipass",
  roles: [{role: "dbOwner", db: "unifi_stat"}]
});
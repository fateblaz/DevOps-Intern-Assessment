#!/bin/bash
set -euo pipefail

for i in {1..30}; do
  if docker exec mongo mongo --eval "db.adminCommand('ping')" >/dev/null 2>&1; then break; fi
  sleep 2
done


MONGO_USER=$(aws ssm get-parameter --name "${ssm_param_user}" --with-decryption --query "Parameter.Value" --output text --region "${aws_region}" 2>/dev/null) || true
MONGO_PW=$(aws ssm get-parameter --name "${ssm_param_password}" --with-decryption --query "Parameter.Value" --output text --region "${aws_region}" 2>/dev/null) || true

if [ -z "${MONGO_USER}" ] || [ -z "${MONGO_PW}" ]; then
  echo "ERROR: cannot fetch SSM parameters for mongo admin. user:${ssm_param_user} pass:${ssm_param_password}" >&2
  exit 2
fi


docker exec mongo mongo admin --eval "try { db.createUser({user: '${MONGO_USER}', pwd: '${MONGO_PW}', roles:[{role:'root', db:'admin'}]}); } catch(e) { print('createUser: ' + e); }" || true


docker exec mongo mongo --username "${MONGO_USER}" --password "${MONGO_PW}" --authenticationDatabase admin --eval '
  db = db.getSiblingDB("sampledb");


  db.createCollection("users");
  db.createCollection("orders");
  db.createCollection("products");


  db.users.updateOne({_id:1}, {$setOnInsert:{name:"Alice", email:"alice@example.com", role:"admin"}}, {upsert:true});
  db.users.updateOne({_id:2}, {$setOnInsert:{name:"Bob", email:"bob@example.com", role:"user"}}, {upsert:true});
  db.users.updateOne({_id:3}, {$setOnInsert:{name:"Charlie", email:"charlie@example.com", role:"user"}}, {upsert:true});
  db.users.updateOne({_id:4}, {$setOnInsert:{name:"Diana", email:"diana@example.com", role:"user"}}, {upsert:true});


  db.products.updateOne({_id:100}, {$setOnInsert:{name:"Widget", price:19.99, stock:120, tags:["hardware","basic"]}}, {upsert:true});
  db.products.updateOne({_id:101}, {$setOnInsert:{name:"Gadget", price:39.50, stock:80, tags:["electronics","featured"]}}, {upsert:true});
  db.products.updateOne({_id:102}, {$setOnInsert:{name:"SuperWidget", price:29.99, stock:50, tags:["hardware","premium"]}}, {upsert:true});
  db.products.updateOne({_id:103}, {$setOnInsert:{name:"UltraGadget", price:54.99, stock:30, tags:["electronics","elite"]}}, {upsert:true});


  db.orders.updateOne({_id:500}, {$setOnInsert:{user_id:1, product_id:100, qty:2, status:"delivered"}}, {upsert:true});
  db.orders.updateOne({_id:501}, {$setOnInsert:{user_id:2, product_id:101, qty:1, status:"processing"}}, {upsert:true});
  db.orders.updateOne({_id:502}, {$setOnInsert:{user_id:3, product_id:102, qty:3, status:"delivered"}}, {upsert:true});
  db.orders.updateOne({_id:503}, {$setOnInsert:{user_id:4, product_id:103, qty:1, status:"cancelled"}}, {upsert:true});
  db.orders.updateOne({_id:504}, {$setOnInsert:{user_id:1, product_id:103, qty:2, status:"pending"}}, {upsert:true});
'

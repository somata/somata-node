# API

## High level

### Client

* Outgoing
	* Public
		* `remote(service_name, method_name, args..., on_response) -> message_id`
		* `subscribe(service_name, event_name, args..., on_event) -> subscription_id`
		* `unsubscribe(subscription_id)`
		* `unsubscribeAll()`
	* Private
		* `getServiceConnection(service_name) -> service_instance`
		* `connectToService(service_instance)`

### Service

* Outgoing
	* Public
		* `publish(event_name, data)`
	* Private
		* `register(service_name, service_instance) -> service_id`
		* `deregister(service_id)`
		* `sendResponse(client_id, message_id, data)`
		* `sendError(client_id, message_id, data)`
		* `sendEvent(client_id, subscription_id, data)`
* Incoming
	* Private
		* `handleMethod(client_id, method, args)`
		* `handleSubscribe(client_id, event_name)`
		* `handleUnsubscribe(client_id, event_name)`

## Low level

### Connection

* Outgoing
	* Public
		* `sendMethod(method_name, args..., on_response) -> message_id`
		* `sendSubscribe(event_name, args..., on_event) -> subscription_id`
		* `sendUnsubscribe(subscription_id)`
	* Private
		* `send(data, cb) -> message_id`
		* `setPending(message_id, cb)`
		* `close()`
* Incoming
	* Private
		* `handleMessage(data)`

### Binding

* `send(client_id, data)`
* `handleMessage(client_id, data)`
# Additional Notes on "telemtry"

## Telemetry Categorisation

{{ mwp }} is designed to manage INAV / MulitWii telemetry and some RC protocols. These essentially breaks down into two types:

* Polled Telemetry: MSP (Multiwii serial protocol). In this case, {{ mwp }} will issue a request for data and the FC will reply;
* _Unsolicited_ Push Telemetry: LTM, INAV flavour MAVLink, CRSF, Smartport, IBus, GCSS MQTT. {{ mwp }} is a passive listener, in particular, it will do nothing to solicit data.

## Implications for data transports

### "Serial" / Point to point

For "dumb" transports (serial UART, Bluetooth), there are no specific implications on telemetry type. The link is essentially physical and there is no dependency on either party to provide a "reply address".

### IP Protocols

#### TCP

{{ mwp }} implements a TCP Client, so it needs a "listener" to which it can connect. This will always work for (polled) MSP, and may work for push protocols if the peer starts the push without specific request on connect.

#### UDP

UDP is slightly more problematic as the both ends need to know the respective peer address. This is typically retrieved from a received packet (e.g. `getpeername`).

For polled telemetry, specify the peer address URI as `udp://peer:port`. The peer will know where to send the reply from the sender address in the request packet sent by {{ mwp }}.

For peer pushed telemetry, mwp does not send anything, so it is set up as a UDP listener; `udp://:port` (note there is no peer name, `INADDR_ANY`, `[::]`, `0.0.0.0` is implicit. {{ mwp }} does not require to even evince the peer name, as it may not return any data.

#### UDP Special cases

Some devices require that both the UDP sender and receiver use the same port. Early (e.g. 2015vintage ESP-01 Serial - IP devices) had this requirement. This may be specified using the `bind` parameter in the device URI e.g.:

```
# both sides use port 14014, remote (FC) is host name "esp-air"
udp://esp-air:14014/?bind=14014
```

Not that for a push telemetry protocol, this does not absolve the remote of the requirement to push unsolicited telemetry data.

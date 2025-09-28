# rtl_433 Home Assistant Add-on

## About

This add-on is a simple wrapper around the excellent [rtl_433](https://github.com/merbanan/rtl_433) project that receives wireless sensor data via [one of the supported SDR dongles](https://triq.org/rtl_433/HARDWARE.html), decodes and outputs it in a variety of formats including JSON and MQTT. The wireless sensors rtl_433 understands transmit data mostly on 433.92 MHz, 868 MHz, 315 MHz, 345 MHz, and 915 MHz ISM bands.

## SDR Driver Information

**Important**: There are multiple RTL-SDR driver repositories with confusingly similar names but different functionality. The main ones include:

- [osmocom/rtl-sdr](https://github.com/osmocom/rtl-sdr) - The original upstream repository
- [librtlsdr/librtlsdr](https://github.com/librtlsdr/librtlsdr) - Hayati Ayguen's fork with extensive enhancements
- [rtlsdrblog/rtl-sdr-blog](https://github.com/rtlsdrblog/rtl-sdr-blog) - Modified drivers for RTL-SDR Blog hardware
- [steve-m/librtlsdr](https://github.com/steve-m/librtlsdr) - Another older fork

This add-on uses [Hayati Ayguen's librtlsdr fork](https://github.com/librtlsdr/librtlsdr) which provides enhanced functionality over the original osmocom drivers, including better tuner control, additional bandwidth options, and improved compatibility with modern RTL-SDR hardware like the RTL-SDR Blog V4. Importantly, this fork supports bias tee control for the RTL-SDR Blog V4 dongles (set `bias_tee 1` in your rtl_433 config file to enable).

Note: rtl_433 supports both rtl-sdr and [SoapySDR](https://github.com/pothosware/SoapySDR), but this add-on only includes rtl-sdr support to keep the container size manageable. If you need SoapySDR support, you would need to modify the Dockerfile to build and include the SoapySDR library and its drivers.

[View the rtl_433 documentation](https://triq.org/rtl_433)

## How it works

The only thing this add-on does is run rtl_433 under the Home Assistant OS supervisor. When you first start the add-on, it automatically creates a default configuration file in the addon's config directory that's pre-configured to connect to Home Assistant's MQTT broker.

You can customize the configuration by editing the template files in the addon config directory or by creating additional `.conf.template` files for multiple radios.

Once you get the rtl_433 sensor data into MQTT, you'll need to help Home Assistant discover and make sense of it. You can do that in a number of ways:

  * manually configure `sensors` and `binary_sensors` in HA and [link them to the appropriate MQTT topics](https://www.home-assistant.io/integrations/sensor.mqtt/) coming out of rtl_433,
  * run the [rtl_433_mqtt_hass.py](https://github.com/merbanan/rtl_433/tree/master/examples/rtl_433_mqtt_hass.py) script manually or on a schedule to do most of the configuration automatically, or
  * install the [rtl_433 MQTT Auto Discovery Home Assistant Add-on](https://github.com/pbkhrv/rtl_433-hass-addons/tree/main/rtl_433_mqtt_autodiscovery), which runs rtl_433_mqtt_hass.py for you.

## Prerequisites

 To use this add-on, you need the following:

 1. [An SDR dongle supported by rtl_433](https://triq.org/rtl_433/HARDWARE.html).

 2. Home Assistant OS running on a machine with the SDR dongle plugged into it.

 3. Some wireless sensors supported by rtl_433. The full list of supported protocols and devices can be found under "Supported device protocols" section of the [rtl_433's README](https://github.com/merbanan/rtl_433/blob/master/README.md).

## Installation

 1. Install the add-on.

 2. Plug your SDR dongle to the machine running the add-on.

 3. Start the add-on. A default configuration will be created in the addon's config directory that's pre-configured to connect to Home Assistant's MQTT broker.

 4. Check the logs to see if rtl_433 is detecting your wireless sensors.

 5. Customize the configuration by editing `rtl_433.conf.template` to specify frequency bands, protocols, and other settings for your specific hardware and sensors. You can view the [default template](rtl_433.conf.template) for reference, or create additional `.conf.template` files for multiple radios.

## Accessing Configuration Files

The addon stores configuration files in `/addon_configs/2b3c960e_rtl433/` on your Home Assistant host. To access and edit these files:

1. Install the File Editor addon from the Home Assistant addon store (found under Official add-ons)
2. Go to the File Editor addon configuration
3. Turn off "Enforce Basepath" to allow navigation outside the `/homeassistant` directory
4. Navigate to `/addon_configs/2b3c960e_rtl433/` to find your configuration files

Alternatively, you can access these files directly if you have SSH access to your Home Assistant host.

## Configuration

For a "zero configuration" setup, install the [Mosquitto broker](https://github.com/home-assistant/addons/blob/master/mosquitto/DOCS.md) addon. While other brokers may work, they are not tested and will require manual setup. Once the addon is installed, start or restart the rtl_433 and rtl_433_mqtt_autodiscovery addons to start capturing known 433 MHz protocols.

For more advanced configuration, take a look at the example config file included in the rtl_433 source code: [rtl_433.example.conf](https://github.com/merbanan/rtl_433/blob/master/conf/rtl_433.example.conf)

Note that the configuration template files support variable substitution for MQTT connection details (`${host}`, `${port}`, `${username}`, `${password}`, `${retain}`). If you need to use literal dollar signs for other purposes, **escape them with backslashes**. For example, to use the literal string `$GPRMC` in the configuration file, use `\$GPRMC`.

The `retain` option controls if MQTT's `retain` flag is enabled or disabled by default. It can be overridden on a per-radio basis by setting `retain` to `true` or `false` in the `output` setting.

When configuring manually, assuming that you intend to get the rtl_433 data into Home Assistant, the absolute minimum that you need to specify in the config file is the [MQTT connection and authentication information](https://triq.org/rtl_433/OPERATION.html#mqtt-output):

```
output      mqtt://HOST:PORT,user=XXXX,pass=YYYYYYY
```

rtl_433 defaults to listening on 433.92MHz, but even if that's what you need, it's probably a good idea to specify the frequency explicitly to avoid confusion:

```
frequency   433.92M
```

You might also want to narrow down the list of protocols that rtl_433 should try to decode. The full list can be found under "Supported device protocols" section of the [README](https://github.com/merbanan/rtl_433/blob/master/README.md). Let's say you want to listen to Acurite 592TXR temperature/humidity sensors:

```
protocol    40
```

Last but not least, if you decide to use the MQTT auto discovery script or add-on, its documentation recommends converting units in all of the data coming out of rtl_433 into SI:

```
convert     si
```

Assuming you have only one USB dongle attached and rtl_433 is able to automatically find it, we arrive at a minimal rtl_433 config file that looks like this:

```
output      mqtt://HOST:PORT,user=XXXX,pass=YYYYYYY

frequency   433.92M
protocol    40

convert     si
```

Please check [the official rtl_433 documentation](https://triq.org/rtl_433) and [config file examples](https://github.com/merbanan/rtl_433/tree/master/conf) for more information.

## Credit

This add-on is based on [pbkhrv's rtl_433-hass-addons](https://github.com/pbkhrv/rtl_433-hass-addons) repository. For automatic MQTT discovery of rtl_433 devices in Home Assistant, see pbkhrv's excellent [rtl_433_mqtt_autodiscovery add-on](https://github.com/pbkhrv/rtl_433-hass-addons/tree/main/rtl_433_mqtt_autodiscovery).

The original lineage traces back to James Fry's [rtl4332mqtt Hass.IO Add-on](https://github.com/james-fry/hassio-addons/tree/master/rtl4332mqtt), which is in turn based on Chris Kacerguis' project here: [https://github.com/chriskacerguis/honeywell2mqtt](https://github.com/chriskacerguis/honeywell2mqtt), which is in turn based on Marco Verleun's rtl2mqtt image here: [https://github.com/roflmao/rtl2mqtt](https://github.com/roflmao/rtl2mqtt).
Investigating D-Bus on GNU/Linux
================================

D-Bus is an integral part of the Linux operating system and in true Linux fashion is heavily used and poorly documented. After hours of scouring the internet, I have pulled together some resources that start to paint a more complete picture of D-Bus, the problem D-Bus solves and how to interact with it programatically (in C/C++).

D-Bus at its essence is a message passing system that facilitates interprocess communication and generically abstracts a service's functionality. This allows a service to provide functionality and information in such a way that it can be accessed across process boundaries, language boundaries, licensing restrictions and even network boundaries!

Hop on the bus, Gus
-------------------

As you may have guessed, D-Bus behaves like a bus. As we all know, a bus is of no use, unless you are connected. In order to get connected, you will need to execute the following code.

```c++
DBusConnection * dbus_conn = nullptr;
DBusError dbus_error;

// Initialize D-Bus error
::dbus_error_init(&dbus_error);

// Connect to D-Bus
dbus_conn = ::dbus_bus_get(DBUS_BUS_SYSTEM, &dbus_error);
std::cout << "Connected to D-Bus as \"" << ::dbus_bus_get_unique_name(dbus_conn) << "\"." << std::endl;
```

Bango, now you're on the bus! Now you have access to every service connected to D-Bus (i.e. Bluetooth, network manager, system power information, etc...). The services on D-Bus are exposed via interfaces, which describe methods, events and properties. If you are familiar with object-oriented programming this should all be very intuitive.

> ***PROTIP:** If you are an Ubuntu user, and you would like to see the D-Bus mechanism in action, then download [D-Feet](https://apps.ubuntu.com/cat/applications/d-feet/) from the Ubuntu App Store and you can easily navigate through the services exposed via D-Bus.*

#### See Also

- [D-Bus Bus API](https://dbus.freedesktop.org/doc/api/html/group__DBusBus.html#ga8a9024c78c4ea89b6271f19dbc7861b2)

Operator, well could you help me place this call?
-------------------------------------------------

All D-Bus services should provide an interface called `Introspectable` with a single method called `Introspect` (*if you are familiar with **DCOM** on Windows, then you should feel right at home*). This allows you to recurse through each service made available via D-Bus. You are able to discover all methods, properties and events, by using the interfaces defined in the XML string resulting from the call to `Introspect`.

The easiest place to start is to query D-Bus itself. First, you will need to formulate a message for the D-Bus daemon (the operator) to pass on to the D-Bus service. You can accomplish this call, using the following code.

```c++
DBusMessage * dbus_msg = nullptr;
DBusMessage * dbus_reply = nullptr;

// Compose remote procedure call
dbus_msg = ::dbus_message_new_method_call("org.freedesktop.DBus", "/", "org.freedesktop.DBus.Introspectable", "Introspect");

// Invoke remote procedure call, block for response
dbus_reply = ::dbus_connection_send_with_reply_and_block(dbus_conn, dbus_msg, DBUS_TIMEOUT_USE_DEFAULT, &dbus_error);
```

Eureka! You've just communcated with the system via D-Bus. Take a step back and think about what you've accomplished so far. You have just queried the system! The same pattern will give to access to nearly every service on the system (i.e. bluetooth).

#### See Also

- [D-Bus Connection API](https://dbus.freedesktop.org/doc/api/html/group__DBusConnection.html#ga8d6431f17a9e53c9446d87c2ba8409f0)
- [D-Bus Message API](https://dbus.freedesktop.org/doc/api/html/group__DBusMessage.html#gad8953f53ceea7de81cde792e3edd0230)

My baby, just-a wrote me a letter
---------------------------------

So far we have connected to the D-Bus (daemon), we have queried the D-Bus service and we have received a response. *HOWEVER*, we have a message that we can't quite understand. That's because it was *marshalled* into a binary format that is easier and more efficient to send as a message (but more difficult for humans to read).

Now it's time to decode the response message and view the data encoded within. Luckily, the D-Bus developers have provided all the tools necessary to break open the message and get the contents. Use the following code to make sense of the response.

```c++
const char * dbus_result = nullptr;

// Parse response
::dbus_message_get_args(dbus_reply, &dbus_error, DBUS_TYPE_STRING, &dbus_result, DBUS_TYPE_INVALID);

// Work with the results of the remote procedure call
std::cout << "Introspection Result:" << std::endl << std::endl;
std::cout << dbus_result << std::endl;
```

Now we've pulled the string out of the message. The string is XML detailing the interfaces available via the D-Bus. It describes interfaces, methods and their parameters, properties and signals. Below is a snippet of the response from `Introspect`.

```xml
  ...
  <interface name="org.freedesktop.DBus.Introspectable">
    <method name="Introspect">
      <arg direction="out" type="s"/>
    </method>
  </interface>
  ...
```

The snippet above is the `Introspectable` interface we used to get this information. As you can see, it details any available methods (i.e. `Introspect`) along with the parameters and data-types they require (none in this case). Notice that even though we didn't have any parameters to the call, we see the result described as an `out` argument of type `s` (or string).

#### See Also

- [D-Bus Message API](https://dbus.freedesktop.org/doc/api/html/group__DBusMessage.html#gad8953f53ceea7de81cde792e3edd0230)

Take out the papers and the trash
---------------------------------

Well the "hard part" is behind us, and now it's time to clean up. Thinking back on the resources we have allocated, we made a connection, we created a message, we received a message and pulled a string from that message. Let see how we clean up our mess.

At some level, everything involving D-Bus is shared, and at the very least, a message must be shared between two process. Fortunately, we are only responsible for our reference to the memory (even if we created it), which greatly simplifies things. We no longer have to be concerned about when the memory comes or goes. We only need worry about letting the system know when we are finished using the memory (think `std::shared_pointer`). The following code lets the system know we have finished using the messages.

```c++
::dbus_message_unref(dbus_msg);
::dbus_message_unref(dbus_reply);
```

So what about the string we pulled out of the message? Apparently, it gets cleaned up with the message.

D-Bus documentation states:
> "Except for string arrays, the returned values are constant; do not free them. They point into the DBusMessage."

Fair enough, but what about the connection to D-Bus itself? Nope, we leave it alone too. It turns out that we are attaching to a "shared connection", and we are not allowed to close it. In fact, if you try, then the library throws you a nice error message (below) to slap your hand.

> `process nnnn: Applications must not close shared connections - see dbus_connection_close() docs. This is a bug in the application.`

#### See Also

- [D-Bus Message API](https://dbus.freedesktop.org/doc/api/html/group__DBusMessage.html#gad8953f53ceea7de81cde792e3edd0230)

We are family
-------------

When I was learning about D-Bus, I kept running into the following similarly named libraries. They are all in the same domain (D-Bus), and they really muddy the waters when you're trying to learn the basics.

- [`gdbus`](https://www.freedesktop.org/software/gstreamer-sdk/data/docs/2012.5/gio/gdbus.html) - GNOME's D-Bus wrapper/helper library
- [`qtdbus`](http://doc.qt.io/qt-5/qtdbus-index.html) - QT D-Bus wrapper/helper library
- [`kdbus`](https://www.freedesktop.org/wiki/Software/systemd/kdbus/) - A kernel side D-Bus transport layer

The takeaway here, is to learn about D-Bus first. Once you have a firm grasp about the function D-Bus performs, then you can learn about these additional layers that sit atop and beneath D-Bus to make it "easier to use" or "faster" as the case may be.

Summary
-------

At this point, you should have some insight into what D-Bus is, a basic understanding of how to interact with it and even a little sample code to help get you started!

D-Bus in an amazing tool! Not only are you able to access a wealth of system services and resources, but there are also several less obvious benefits. There are bindings in several different high-level languages (i.e. python, javascript, etc...), allowing you to break through language boundaries. Not to mention, the fact that you are invoking a service as a binary, which also has the neat side-effect of allowing you to bypass GNU licensing restrictions!

With this foundation, you now possess the building blocks necessary to interact with BlueZ via D-Bus. Continue on, by reading my follow up post [GNU/Linux BLE via BlueZ](https://makercrew.com/404). It will guide you through the BlueZ D-Bus interface, and you will be well on your way to programmatically interacting with all your bluetooth devices!

_________________________________

D-Bus API
---------

- [Bus API](https://dbus.freedesktop.org/doc/api/html/group__DBusBus.html#ga8a9024c78c4ea89b6271f19dbc7861b2)
- [Connection API](https://dbus.freedesktop.org/doc/api/html/group__DBusConnection.html#ga8d6431f17a9e53c9446d87c2ba8409f0)
- [Error API](https://dbus.freedesktop.org/doc/api/html/group__DBusErrors.html#ga8937f0b7cdf8554fa6305158ce453fbe)
- [Message API](https://dbus.freedesktop.org/doc/api/html/group__DBusMessage.html#gad8953f53ceea7de81cde792e3edd0230)

More Info
---------

- [D-Bus Tutorial](https://dbus.freedesktop.org/doc/dbus-tutorial.html)
- [D-Bus Specification](https://dbus.freedesktop.org/doc/dbus-specification.html)
  - [Standard Interfaces](https://dbus.freedesktop.org/doc/dbus-specification.html#standard-interfaces)

Other Examples
--------------

- [Using the D-Bus C API](http://www.matthew.ath.cx/misc/dbus)
- [Compiling D-Bus Programs](https://stackoverflow.com/questions/14263390/how-to-compile-a-basic-d-bus-glib-example)

Applications
------------

- [D-Feet](https://apps.ubuntu.com/cat/applications/d-feet/) - A D-Bus exploration application

Code
----

```c++
/* Created and copyrighted by Zachary J. Fields. Offered as open source under the MIT License (MIT). */

/*
 * Filename: dbus.cpp
 *
 * Purpose: A simple sample of a D-Bus interaction.
 */

#include <dbus/dbus.h>

#include <cstddef>
#include <cstdio>
#include <iostream>

int
main (
  int argc,
  char * argv[]
) {
    (void)argc;
    (void)argv;
    DBusError dbus_error;
    DBusConnection * dbus_conn = nullptr;
    DBusMessage * dbus_msg = nullptr;
    DBusMessage * dbus_reply = nullptr;
    const char * dbus_result = nullptr;

    // Initialize D-Bus error
    ::dbus_error_init(&dbus_error);

    // Connect to D-Bus
    if ( nullptr == (dbus_conn = ::dbus_bus_get(DBUS_BUS_SYSTEM, &dbus_error)) ) {
        ::perror(dbus_error.name);
        ::perror(dbus_error.message);

    // Compose remote procedure call
    } else if ( nullptr == (dbus_msg = ::dbus_message_new_method_call("org.freedesktop.DBus", "/", "org.freedesktop.DBus.Introspectable", "Introspect")) ) {
        ::perror("ERROR: ::dbus_message_new_method_call - Unable to allocate memory for the message!");

    // Invoke remote procedure call, block for response
    } else if ( nullptr == (dbus_reply = ::dbus_connection_send_with_reply_and_block(dbus_conn, dbus_msg, DBUS_TIMEOUT_USE_DEFAULT, &dbus_error)) ) {
        ::dbus_message_unref(dbus_msg);
        ::perror(dbus_error.name);
        ::perror(dbus_error.message);

    // Parse response
    } else if ( !::dbus_message_get_args(dbus_reply, &dbus_error, DBUS_TYPE_STRING, &dbus_result, DBUS_TYPE_INVALID) ) {
        ::dbus_message_unref(dbus_msg);
        ::dbus_message_unref(dbus_reply);
        ::perror(dbus_error.name);
        ::perror(dbus_error.message);

    // Work with the results of the remote procedure call
    } else {
        std::cout << "Connected to D-Bus as \"" << ::dbus_bus_get_unique_name(dbus_conn) << "\"." << std::endl;
        std::cout << "Introspection Result:" << std::endl << std::endl;
        std::cout << dbus_result << std::endl;
        ::dbus_message_unref(dbus_msg);
        ::dbus_message_unref(dbus_reply);

        /*
         * Applications must not close shared connections -
         * see dbus_connection_close() docs. This is a bug in the application.
         */
        //::dbus_connection_close(dbus_conn);
    }

    return 0;
}

/* Created and copyrighted by Zachary J. Fields. Offered as open source under the MIT License (MIT). */
```

#### Compile Command

```bash
$ g++ dbus.cpp -std=c++0x $(pkg-config dbus-1 --cflags) -ldbus-1 -Werror -Wall -Wextra
```

> ***NOTE:** You may have noticed the funky `$(pkg-config dbus-1 --cflags)` string in the compile arguments. This allows D-Bus to support different configurations on different systems. I ran into this exact scenario while creating the Docker container for an Alpine system, after developing on Ubuntu.*

#### Docker Environment

If you have Docker installed, then I have provided a container. The container houses all the necessary dependencies (including the D-Bus daemon), and allows you to play with D-Bus and the sample, without having to make any modifications to your host machine.

##### Create D-Bus Environment

```bash
$ docker run -d --name dbus-sample --rm makercrew/dbus-sample
```

For those of you who are unfamiliar with Docker, I would like to assure you this is one of the safest bits of sample code you can run. The container provides a sandbox that traps the application. We have  not specified any flags that would break the sandbox, thus providing access to your machine (_i.e. `--privileged`, `--volume`, `--network host`, etc...).

The specified flags provide the following behavior:

- `-d` - the process associated with this container will run as a background ("detached") process on the host (_your machine_)
- `--name` - the name specified for the process (_if not supplied, Docker will create one for you_)
- `--rm` - when this process is stopped, remove the container associated with the process

Congratulations, you have now launched the D-Bus deamon as a detached process inside a Docker container (_a fully sandboxed process_)!

##### Play Around

```bash
$ docker exec --interactive --tty dbus-sample /bin/ash
# cd dbus-sample/
# ls
```

The specified flags provide the following behavior:

- `--interactive` - the user (_you_) is requesting interactive shell access to the application
- `--tty` -  allocate a pseudo-TTY for the container process

The `docker exec` command allows you to attach to the container hosting the D-Bus daemon (_launched in the previous step_). The subsequent commands, with the `#` prefix, are commands that will be executed within the context of the container.
Once you have executed the preceding commands, you will see the contents of this repository presented to you. You can now execute the sample above, or modify and experiment; even on Windows and Mac!

##### Clean Environment

```bash
$ docker stop dbus-sample
```

Once you have finished playing, be sure to kill the background (_detached_) process. In doing so, the supporting container will be cleaned up by the Docker daemon, courtesy of the `--rm` flag we passed to the original `docker run` command.

> ***NOTE:** This is an Alpine based container (to save you space), and there are a couple of things you may not be familiar with and are worth calling out. This container uses the Almquist shell, `ash`, and the Alpine Linux Package Manager, `apk`.*

 If you aren't familiar with Docker, then you're missing out! Be sure to watch [Kevin Sidwar's vlog about Docker](https://makercrew.com/404).

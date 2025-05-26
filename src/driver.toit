// Copyright (C) 2021 Toitware ApS. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import io
import i2c

I2C-ADDRESS      ::= 0x4A
I2C-ADDRESS-ALT  ::= 0x4B

FREQUENCY-0-5HZ ::= 0
FREQUENCY-1HZ   ::= 1
FREQUENCY-2HZ   ::= 2
FREQUENCY-4HZ   ::= 3
FREQUENCY-10HZ  ::= 4

ACCURACY-HIGH   ::= 0
ACCURACY-MEDIUM ::= 1
ACCURACY-LOW    ::= 2

/**
Driver for STS3x-DIS high-accuracy digital temperature sensors.
*/
class Driver:
  static COMMAND-SINGLE-SHOT_ ::= [
    #[0x2C, 0x06],
    #[0x2C, 0x0D],
    #[0x2C, 0x10],
  ]
  static COMMAND-PERIODIC_ ::= [
    [
      #[0x20, 0x32],
      #[0x20, 0x24],
      #[0x20, 0x2F],
    ], [
      #[0x21, 0x30],
      #[0x21, 0x26],
      #[0x21, 0x2D],
    ], [
      #[0x22, 0x36],
      #[0x22, 0x20],
      #[0x22, 0x2B],
    ], [
      #[0x23, 0x34],
      #[0x23, 0x22],
      #[0x23, 0x29],
    ], [
      #[0x27, 0x37],
      #[0x27, 0x21],
      #[0x27, 0x2A],
    ]
  ]
  static COMMAND-BREAK_       ::= #[0x30, 0x93]
  static COMMAND-FETCH-DATA_  ::= #[0xE0, 0x00]

  device_/i2c.Device

  read-command_/ByteArray? := null

  /**
  Constructs the driver in single-shot, high accuracy measure mode.

  Call $read for reading the next value.
  */
  constructor .device_:
    configure

  /**
  Configures the chip.

  Set $periodic to have the chip automatically measure at the chosen $frequency.
  */
  configure --periodic/bool=false --frequency=FREQUENCY-10HZ --accuracy=ACCURACY-HIGH:
    device_.write COMMAND-BREAK_

    if periodic:
      command := COMMAND-PERIODIC_[frequency][accuracy]
      device_.write command
      read-command_ = COMMAND-FETCH-DATA_
    else:
      read-command_ = COMMAND-SINGLE-SHOT_[accuracy]

  /**
  Closes the device for reading.
  */
  close:
    device_.write COMMAND-BREAK_

  /**
  Reads out the next value.

  This method blocks until the next measured value is available. For single-shot mode,
    this will also trigger the chip to perform a measure.
  */
  read -> float:
    with-timeout --ms=2500:
      while true:
        device_.write read-command_
        value := read-and-validate_
        if value:
          return -45.0 + (175 * value).to-float / int.MAX-U16
        sleep --ms=50
    unreachable

  read-and-validate_ -> int?:
    catch:
      data := device_.read 3
      checksum := crc8_ data[0..2]
      if data[2] != checksum: throw "CRC_CHECK_FAILED"
      return io.BIG-ENDIAN.uint16 data 0
    return null

  static crc8_ data/ByteArray -> int:
    crc := 0xff
    data.do:
      crc ^= it;
      8.repeat:
        if crc & 0x80 != 0:
          crc = ((crc << 1) ^ 0x31) & 0xff
        else:
          crc <<= 1;
          crc &= 0xff
    return crc

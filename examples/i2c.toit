// Copyright (C) 2021 Toitware ApS. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import i2c
import gpio

import sts3x

SDA := gpio.Pin 21
SCL := gpio.Pin 22

main:
  bus := i2c.Bus --sda=SDA --scl=SCL
  device := bus.device sts3x.I2C_ADDRESS
  driver := sts3x.Driver device

  driver.configure --periodic --frequency=sts3x.FREQUENCY_1HZ
  while true:
    print driver.read
    sleep --ms=1000

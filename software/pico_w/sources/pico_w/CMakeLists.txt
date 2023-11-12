add_executable(picow_symdcf77_background
        picow_symdcf77.c
        )

target_compile_definitions(picow_symdcf77_background PRIVATE
        WIFI_SSID=\"${WIFI_SSID}\"
        WIFI_PASSWORD=\"${WIFI_PASSWORD}\"
        )
target_include_directories(picow_symdcf77_background PRIVATE
        ${CMAKE_CURRENT_LIST_DIR}
        ${CMAKE_CURRENT_LIST_DIR}/.. # for our common lwipopts
)
target_link_libraries(picow_symdcf77_background
        pico_cyw43_arch_lwip_threadsafe_background
        pico_stdlib
        hardware_rtc
        )

pico_enable_stdio_usb(picow_symdcf77_background 1)
pico_enable_stdio_uart(picow_symdcf77_background 0)

pico_add_extra_outputs(picow_symdcf77_background)

add_executable(picow_symdcf77_poll
        picow_symdcf77.c
        )
target_compile_definitions(picow_symdcf77_poll PRIVATE
        WIFI_SSID=\"${WIFI_SSID}\"
        WIFI_PASSWORD=\"${WIFI_PASSWORD}\"
        )
target_include_directories(picow_symdcf77_poll PRIVATE
        ${CMAKE_CURRENT_LIST_DIR}
        ${CMAKE_CURRENT_LIST_DIR}/.. # for our common lwipopts
        )
target_link_libraries(picow_symdcf77_poll
        pico_cyw43_arch_lwip_poll
        pico_stdlib
        )
pico_add_extra_outputs(picow_symdcf77_poll)

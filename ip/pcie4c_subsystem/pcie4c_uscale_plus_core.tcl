set pcie4c_uscale_plus pcie4c_uscale_plus_core
create_ip -name pcie4c_uscale_plus -vendor xilinx.com -library ip -module_name $pcie4c_uscale_plus
set_property -dict {
    CONFIG.mode_selection               {Advanced}
    CONFIG.PL_LINK_CAP_MAX_LINK_WIDTH   {X16}
    CONFIG.PL_LINK_CAP_MAX_LINK_SPEED   {8.0_GT/s}

    CONFIG.xlnx_ref_board               {AU50}
    CONFIG.SYS_RST_N_BOARD_INTERFACE    {pcie_perstn}
    CONFIG.PCIE_BOARD_INTERFACE         {pci_express_x16}
    CONFIG.en_transceiver_status_ports  {false}
    CONFIG.axisten_if_enable_client_tag {true}

    CONFIG.axisten_freq                        {250}
    CONFIG.axisten_if_width                    {512_bit}

    CONFIG.AXISTEN_IF_CQ_ALIGNMENT_MODE        {DWORD_Aligned}
    CONFIG.AXISTEN_IF_EXT_512_CQ_STRADDLE      {false}
    CONFIG.AXISTEN_IF_EXT_512_CC_STRADDLE      {false}

    CONFIG.AXISTEN_IF_RQ_ALIGNMENT_MODE        {DWORD_Aligned}
    CONFIG.AXISTEN_IF_EXT_512_RQ_STRADDLE      {true}
    CONFIG.AXISTEN_IF_EXT_512_RC_4TLP_STRADDLE {true}

    CONFIG.vendor_id               {1234}
    CONFIG.PF0_DEVICE_ID           {0001}
    CONFIG.PF0_SUBSYSTEM_VENDOR_ID {1234}

    CONFIG.tl_pf_enable_reg        {1}

    CONFIG.pf0_base_class_menu          {Network_controller}
    CONFIG.pf0_class_code_base          {02}
    CONFIG.pf0_class_code_interface     {00}
    CONFIG.pf0_class_code_sub           {80}
    CONFIG.pf0_sub_class_interface_menu {Other_network_controller}
    CONFIG.PF0_CLASS_CODE               {058000}

    CONFIG.pf0_bar0_enabled             {true}
    CONFIG.pf0_bar0_64bit               {false}
    CONFIG.pf0_bar0_prefetchable        {false}
    CONFIG.pf0_bar0_scale               {Megabytes}
    CONFIG.pf0_bar0_size                {4}
    CONFIG.pf0_bar0_type                {Memory}

    CONFIG.pf0_bar1_enabled             {false}
    CONFIG.pf0_bar2_enabled             {false}
    CONFIG.pf0_bar3_enabled             {false}
    CONFIG.pf0_bar4_enabled             {false}
    CONFIG.pf0_bar5_enabled             {false}

    CONFIG.pf0_msi_enabled              {false}
    CONFIG.pf0_msix_enabled             {false}
    CONFIG.pf1_msi_enabled              {false}
    CONFIG.pf1_msix_enabled             {false}
    CONFIG.pf2_msi_enabled              {false}
    CONFIG.pf2_msix_enabled             {false}
    CONFIG.pf3_msi_enabled              {false}
    CONFIG.pf3_msix_enabled             {false}
    CONFIG.use_msix_pfs_for_vfs         {false}
    CONFIG.interrupt_interface          {false}
    CONFIG.pf0_tphr_cap_int_vec_mode    {false}
} [get_ips $pcie4c_uscale_plus]

(** Data Model and Message Specification for Xen Management Tools *)

(* ------------------------------------------------------------------

   Copyright (c) 2006-2007 Xensource Inc

   Contacts: Dave Scott    <dscott@xensource.com>
             Richard Sharp <richard.sharp@xensource.com>
             Ewan Mellor   <ewan.mellor@xensource.com>
 
   Data Model and Message Specification for Xen Management Tools

   ------------------------------------------------------------------- *)

open Datamodel_types

(* IMPORTANT: Please bump schema vsn if you change/add/remove a _field_.
              You do not have to bump vsn if you change/add/remove a message *)
let schema_major_vsn = 5
let schema_minor_vsn = 59

(* Historical schema versions just in case this is useful later *)
let rio_schema_major_vsn = 5
let rio_schema_minor_vsn = 19

let miami_release_schema_major_vsn = 5
let miami_release_schema_minor_vsn = 35

let orlando_release_schema_major_vsn = 5
let orlando_release_schema_minor_vsn = 55

(* the schema vsn of the last release: used to determine whether we can upgrade or not.. *)
let last_release_schema_major_vsn = 5
let last_release_schema_minor_vsn = 57

(** Bindings for currently specified releases *)

(** Name of variable which refers to reference in the parameter list *)
let _self = "self"

(** All the various object names *)

let _session = "session"
let _task = "task"
let _user = "user"
let _host = "host"
let _host_metrics = "host_metrics"
let _host_crashdump = "host_crashdump"
let _host_patch = "host_patch"
let _hostcpu = "host_cpu"
let _sr = "SR"
let _sm = "SM"
let _vm = "VM"
let _vm_metrics = "VM_metrics"
let _vm_guest_metrics = "VM_guest_metrics"
let _network = "network"
let _vif = "VIF"
let _vif_metrics = "VIF_metrics"
let _pif = "PIF"
let _pif_metrics = "PIF_metrics"
let _bond = "Bond"
let _vlan = "VLAN"
let _pbd = "PBD"
let _vdi = "VDI"
let _vbd = "VBD"
let _vbd_metrics = "VBD_metrics"
let _vtpm = "VTPM"
let _console = "console"
let _event = "event"
let _alert = "alert"
let _crashdump = "crashdump"
let _pool = "pool"
let _pool_patch = "pool_patch"
let _data_source = "data_source"
let _blob = "blob"
let _message = "message"
let _auth = "auth"
let _subject = "subject"
let _role = "role"

(******************************************************************************************************************)
(* Define additional RPCs for objects *)

let errors = Hashtbl.create 10
let messages = Hashtbl.create 10

exception UnspecifiedRelease

let get_oss_releases in_oss_since =
  match in_oss_since with
    None -> []
  | Some "3.0.3" -> ["3.0.3"]
  | _ -> raise UnspecifiedRelease

let get_product_releases in_product_since =
  let rec go_through_release_order rs =
    match rs with
      [] -> raise UnspecifiedRelease
    | x::xs -> if x=in_product_since then "closed"::x::xs else go_through_release_order xs
  in go_through_release_order release_order

let midnight_ride_release =
	{ internal=get_product_releases "midnight-ride"
	; opensource=get_oss_releases None
	; internal_deprecated_since=None
	}

let george_release =
	{ internal=get_product_releases "george"
	; opensource=get_oss_releases None
	; internal_deprecated_since=None
	}

let orlando_release =
	{ internal=get_product_releases "orlando"
	; opensource=get_oss_releases None
	; internal_deprecated_since=None
	}

let miami_symc_release =
	{ internal=get_product_releases "symc"
	; opensource=get_oss_releases None
	; internal_deprecated_since=None
	}

let miami_release =
	{ internal=get_product_releases "miami"
	; opensource=get_oss_releases None
	; internal_deprecated_since=None
	}

let rio_release =
	{ internal=get_product_releases "rio"
	; opensource=get_oss_releases (Some "3.0.3")
	; internal_deprecated_since=None
	}

let call ~name ?(doc="") ?(in_oss_since=Some "3.0.3") ~in_product_since ?internal_deprecated_since
    ?result ?(flags=[`Session;`Async])
    ?(effect=true) ?(tag=Custom) ?(errs=[]) ?(custom_marshaller=false) ?(db_only=false)
    ?(no_current_operations=false) ?(secret=false) ?(hide_from_docs=false)
    ?(pool_internal=false)
    ?(params=[]) ?versioned_params () = 
  (* if you specify versioned_params then these get put in the params field of the message record;
     otherwise params go in with no default values and param_release=call_release...
  *)
  let call_release = {internal=get_product_releases in_product_since; 
		      opensource=get_oss_releases in_oss_since;
		      internal_deprecated_since = internal_deprecated_since;
		     } in
  { 
    msg_name = name;
    msg_params =
      (match versioned_params with
	 None ->
	   List.map (fun (ptype, pname, pdoc) -> {param_type=ptype; param_name=pname; param_doc=pdoc; param_release=call_release; param_default=None}) params
       | Some ps -> ps);
    msg_result = result; msg_doc = doc;
    msg_session = List.mem `Session flags; msg_async = List.mem `Async flags;
    msg_db_only = db_only;
    msg_release = call_release;
    msg_has_effect = effect; msg_tag = tag; msg_obj_name="";
    msg_force_custom = false;
    msg_errors = List.map (Hashtbl.find errors) errs; msg_secret = secret;
    msg_custom_marshaller = custom_marshaller;
    msg_no_current_operations = no_current_operations;
    msg_hide_from_docs = hide_from_docs;
    msg_pool_internal = pool_internal
  }

let assert_operation_valid enum cls self = call 
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~name:"assert_operation_valid"
  ~doc:"Check to see whether this operation is acceptable in the current state of the system, raising an error if the operation is invalid for some reason"
  ~params:[Ref cls, self, "reference to the object";
	   enum, "op", "proposed operation" ]
  ()

let update_allowed_operations enum cls self = call
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~name:"update_allowed_operations"
  ~doc:"Recomputes the list of acceptable operations"
  ~params:[Ref cls, self, "reference to the object"]
  ()

(** Compute an enum constant corresponding to an operation, for current_operations,
    allowed_operations.*)
let operation_enum x = 
    x.msg_name, Printf.sprintf "refers to the operation \"%s\"" x.msg_name 

let error name params ?(doc="") () =
  Hashtbl.add errors name {
    err_name = name;
    err_params = params;
    err_doc = doc;
  }

let message name ?(doc="") () =
  Hashtbl.add messages name {
    mess_name = name;
    mess_doc = doc;
  }

let _ =
  (* Internal *)
  error Api_errors.internal_error ["message"] 
    ~doc:"The server failed to handle your request, due to an internal error.  The given message may give details useful for debugging the problem." ();

  error Api_errors.message_deprecated []
    ~doc:"This message has been deprecated." ();

  error Api_errors.permission_denied ["message"]
    ~doc:"Caller not allowed to perform this operation." ();

  (* Generic errors *)
  (* licensed expired - copied from geneva *)
  error Api_errors.license_expired []
    ~doc:"Your license has expired.  Please contact your support representative." ();
  error Api_errors.license_processing_error []
    ~doc:"There was an error processing your license.  Please contact your support representative." ();
  error Api_errors.license_restriction []
    ~doc:"This operation is not allowed under your license.  Please contact your support representative." ();
  error Api_errors.license_cannot_downgrade_in_pool []
    ~doc:"Cannot downgrade license while in pool. Please disband the pool first, then downgrade licenses on hosts separately." ();
  error Api_errors.license_does_not_support_pooling []
    ~doc:"This host cannot join a pool because it's license does not support pooling" ();
  error Api_errors.license_does_not_support_xha []
    ~doc:"XHA cannot be enabled because this host's license does not allow it" ();

  error Api_errors.cannot_contact_host ["host"]
    ~doc:"Cannot forward messages because the host cannot be contacted.  The host may be switched off or there may be network connectivity problems." ();

  error Api_errors.uuid_invalid [ "type"; "uuid" ]
    ~doc:"The uuid you supplied was invalid." ();
  error Api_errors.object_nolonger_exists []
    ~doc:"The specified object no longer exists." ();
  error Api_errors.map_duplicate_key ["type"; "param_name"; "uuid"; "key"]
    ~doc:"You tried to add a key-value pair to a map, but that key is already there." ();
  error Api_errors.xmlrpc_unmarshal_failure [ "expected"; "received" ]
    ~doc:"The server failed to unmarshal the XMLRPC message; it was expecting one element and received something else." ();
  
  error Api_errors.message_method_unknown ["method"] 
    ~doc:"You tried to call a method that does not exist.  The method name that you used is echoed." ();
  error Api_errors.message_parameter_count_mismatch ["method"; "expected"; "received"] 
    ~doc:"You tried to call a method with the incorrect number of parameters.  The fully-qualified method name that you used, and the number of received and expected parameters are returned." ();
  error Api_errors.value_not_supported ["field"; "value"; "reason"]
    ~doc:"You attempted to set a value that is not supported by this implementation.  The fully-qualified field name and the value that you tried to set are returned.  Also returned is a developer-only diagnostic reason." ();
  error Api_errors.invalid_value ["field"; "value"]
    ~doc:"The value given is invalid" ();
  error Api_errors.field_type_error ["field"]
    ~doc:"The value specified is of the wrong type" ();
  error Api_errors.operation_not_allowed ["reason"]
    ~doc:"You attempted an operation that was not allowed." ();
  error Api_errors.operation_blocked ["ref"; "code"]
    ~doc:"You attempted an operation that was explicitly blocked (see the blocked_operations field of the given object)." ();
  error Api_errors.not_implemented ["function"] 
    ~doc:"The function is not implemented" ();

  (* DB errors *)
  error Api_errors.handle_invalid ["class"; "handle"]
    ~doc:"You gave an invalid object reference.  The object may have recently been deleted.  The class parameter gives the type of reference given, and the handle parameter echoes the bad value given." ();
  error Api_errors.db_uniqueness_constraint_violation ["table";"field";"value"]
    ~doc:"You attempted an operation which would have resulted in duplicate keys in the database." ();
  error Api_errors.location_not_unique ["SR"; "location"]
    ~doc:"A VDI with the specified location already exists within the SR" ();

  (* Session errors *)
  error Api_errors.session_authentication_failed [] 
    ~doc:"The credentials given by the user are incorrect, so access has been denied, and you have not been issued a session handle." ();
  error Api_errors.session_invalid ["handle"] 
    ~doc:"You gave an invalid session reference.  It may have been invalidated by a server restart, or timed out.  You should get a new session handle, using one of the session.login_ calls.  This error does not invalidate the current connection.  The handle parameter echoes the bad value given." ();
  error Api_errors.change_password_rejected [ "msg" ]
    ~doc:"The system rejected the password change request; perhaps the new password was too short?" ();
  error Api_errors.user_is_not_local_superuser [ "msg" ]
    ~doc:"Only the local superuser can execute this operation" ();

  (* PIF/VIF/Network errors *)
  error Api_errors.network_already_connected ["network"; "connected PIF"]
    ~doc:"You tried to create a PIF, but the network you tried to attach it to is already attached to some other PIF, and so the creation failed." ();
  error Api_errors.pif_is_physical ["PIF"]
    ~doc:"You tried to destroy a PIF, but it represents an aspect of the physical host configuration, and so cannot be destroyed.  The parameter echoes the PIF handle you gave." ();
  error Api_errors.pif_is_vlan ["PIF"]
    ~doc:"You tried to create a VLAN on top of another VLAN - use the underlying physical PIF/bond instead" ();

  error Api_errors.pif_vlan_exists ["PIF"]
    ~doc:"You tried to create a PIF, but it already exists." ();
  error Api_errors.pif_vlan_still_exists [ "PIF" ]
    ~doc:"Operation cannot proceed while a VLAN exists on this interface." ();
  error Api_errors.pif_already_bonded [ "PIF" ]
    ~doc:"This operation cannot be performed because the pif is bonded." ();
  error Api_errors.pif_cannot_bond_cross_host []
    ~doc:"You cannot bond interfaces across different hosts." ();
  error Api_errors.pif_bond_needs_more_members []
    ~doc:"A bond must consist of at least two member interfaces" ();
  error Api_errors.pif_configuration_error [ "PIF"; "msg" ]
    ~doc:"An unknown error occurred while attempting to configure an interface." ();
  error Api_errors.invalid_ip_address_specified [ "parameter" ]
    ~doc:"A required parameter contained an invalid IP address" ();
  error Api_errors.pif_is_management_iface [ "PIF" ]
    ~doc:"The operation you requested cannot be performed because the specified PIF is the management interface." ();
  error Api_errors.pif_does_not_allow_unplug [ "PIF" ]
    ~doc:"The operation you requested cannot be performed because the specified PIF does not allow unplug." ();
  error Api_errors.pif_has_no_network_configuration [ ]
    ~doc:"PIF has no IP configuration (mode curently set to 'none')" ();
  error Api_errors.slave_requires_management_iface []
    ~doc:"The management interface on a slave cannot be disabled because the slave would enter emergency mode." ();
  error Api_errors.vif_in_use [ "network"; "VIF" ]
    ~doc:"Network has active VIFs" ();
  error Api_errors.cannot_plug_vif [ "VIF" ]
    ~doc:"Cannot plug VIF" ();

  error Api_errors.mac_does_not_exist [ "MAC" ]
    ~doc:"The MAC address specified doesn't exist on this host." ();
  error Api_errors.mac_still_exists [ "MAC" ]
    ~doc:"The MAC address specified still exists on this host." ();
  error Api_errors.mac_invalid [ "MAC" ]
    ~doc:"The MAC address specified is not valid." ();

  error Api_errors.vlan_tag_invalid ["VLAN"]
    ~doc:"You tried to create a VLAN, but the tag you gave was invalid -- it must be between 0 and 4094.  The parameter echoes the VLAN tag you gave." ();
  error Api_errors.network_contains_vif ["vifs"] 
    ~doc:"The network contains active VIFs and cannot be deleted." ();
  error Api_errors.network_contains_pif ["pifs"] 
    ~doc:"The network contains active PIFs and cannot be deleted." ();
  error Api_errors.device_attach_timeout [ "type"; "ref" ]
    ~doc:"A timeout happened while attempting to attach a device to a VM." ();
  error Api_errors.device_detach_timeout [ "type"; "ref" ]
    ~doc:"A timeout happened while attempting to detach a device from a VM." ();
  error Api_errors.device_detach_rejected [ "type"; "ref"; "msg" ]
    ~doc:"The VM rejected the attempt to detach the device." ();
  error Api_errors.device_not_attached [ "VBD" ]
    ~doc:"The operation could not be performed because the VBD was not connected to the VM." ();
  error Api_errors.pif_device_not_found []
    ~doc:"The specified device was not found." ();

  (* VM specific errors *)
  error Api_errors.vm_is_protected [ "vm" ]
    ~doc:"This operation cannot be performed because the specified VM is protected by xHA" ();
  error Api_errors.vm_no_crashdump_sr ["vm"]
    ~doc:"This VM does not have a crashdump SR specified." ();
  error Api_errors.vm_no_suspend_sr ["vm"]
    ~doc:"This VM does not have a suspend SR specified." ();
  error Api_errors.vm_memory_size_too_low ["vm"]
    ~doc:"The specified VM has too little memory to be started." ();
  error Api_errors.vm_duplicate_vbd_device [ "vm"; "vbd"; "device" ]
    ~doc:"The specified VM has a duplicate VBD device and cannot be started." ();
  error Api_errors.vm_not_resident_here [ "vm"; "host" ]
    ~doc:"The specified VM is not currently resident on the specified host." ();
  error Api_errors.domain_exists [ "vm"; "domid" ]
    ~doc:"The operation could not be performed because a domain still exists for the specified VM." ();
  error Api_errors.cannot_reset_control_domain [ "vm" ]
    ~doc:"The power-state of a control domain cannot be reset." ();
  error Api_errors.vm_cannot_delete_default_template ["vm"]
    ~doc:"You cannot delete the specified default template." ();
  error Api_errors.vm_bad_power_state ["vm"; "expected"; "actual"]
    ~doc:"You attempted an operation on a VM that was not in an appropriate power state at the time; for example, you attempted to start a VM that was already running.  The parameters returned are the VM's handle, and the expected and actual VM state at the time of the call." ();
  error Api_errors.vm_missing_pv_drivers [ "vm" ]
    ~doc:"You attempted an operation on a VM which requires PV drivers to be installed but the drivers were not detected." ();
  error Api_errors.vm_old_pv_drivers [ "vm"; "major"; "minor" ]
    ~doc:"You attempted an operation on a VM which requires a more recent version of the PV drivers. Please upgrade your PV drivers." ();
  error Api_errors.vm_is_template ["vm"]
    ~doc:"The operation attempted is not valid for a template VM" ();
  error Api_errors.other_operation_in_progress ["class"; "object"]
    ~doc:"Another operation involving the object is currently in progress" ();
  error Api_errors.vbd_not_removable_media ["vbd"]
    ~doc:"Media could not be ejected because it is not removable" ();
  error Api_errors.vbd_not_unpluggable ["vbd"]
    ~doc:"Drive could not be hot-unplugged because it is not marked as unpluggable" ();
  error Api_errors.vbd_not_empty ["vbd"]
    ~doc:"Operation could not be performed because the drive is not empty" ();
  error Api_errors.vbd_is_empty ["vbd"]
    ~doc:"Operation could not be performed because the drive is empty" ();
  error Api_errors.vbd_tray_locked ["vbd"]
    ~doc:"This VM has locked the DVD drive tray, so the disk cannot be ejected" ();
  error Api_errors.vbd_cds_must_be_readonly [ ]
    ~doc:"Read/write CDs are not supported" ();
  error Api_errors.vm_hvm_required ["vm"]
    ~doc:"HVM is required for this operation" ();
  error Api_errors.vm_no_vcpus ["vm"]
    ~doc:"You need at least 1 VCPU to start a VM" ();
  error Api_errors.vm_toomany_vcpus ["vm"]
    ~doc:"Too many VCPUs to start this VM" ();
  error Api_errors.host_not_enough_free_memory [ "needed"; "available" ]
    ~doc:"Not enough host memory is available to perform this operation" ();
  error Api_errors.duplicate_vm [ "vm" ]
    ~doc:"Cannot restore this VM because it would create a duplicate" ();
  error Api_errors.vm_snapshot_with_quiesce_failed [ "vm" ]
    ~doc:"The quiesced-snapshot operation failed for an unexpected reason" ();
  error Api_errors.vm_snapshot_with_quiesce_timeout [ "vm" ]
    ~doc:"The VSS plug-in has timed out" ();
  error Api_errors.vm_snapshot_with_quiesce_plugin_does_not_respond [ "vm" ]
    ~doc:"The VSS plug-in cannot be contacted" ();
  error Api_errors.vm_snapshot_with_quiesce_not_supported [ "vm" ]
    ~doc:"The VSS plug-in is not installed on this virtual machine" ();
  error Api_errors.vm_revert_failed [ "vm"; "snapshot" ]
    ~doc:"An error occured while reverting the specified virtual machine to the specified snapshot" ();
  error Api_errors.vm_checkpoint_suspend_failed [ "vm" ]
    ~doc:"An error occured while saving the memory image of the specified virtual machine" ();
  error Api_errors.vm_checkpoint_resume_failed [ "vm" ]
    ~doc:"An error occured while restoring the memory image of the specified virtual machine" ();

  (* Host errors *)
  error Api_errors.host_offline [ "host" ]
    ~doc:"You attempted an operation which involves a host which could not be contacted." ();
  error Api_errors.host_disabled [ "host" ]
    ~doc:"The specified host is disabled." ();
  error Api_errors.host_disabled_until_reboot [ "host" ]
    ~doc:"The specified host is disabled and cannot be re-enabled until after it has rebooted." ();
  error Api_errors.no_hosts_available []
    ~doc:"There were no hosts available to complete the specified operation." ();
  error Api_errors.host_in_emergency_mode []
    ~doc:"Cannot perform operation as the host is running in emergency mode." ();
  error Api_errors.host_cannot_destroy_self [ "host" ]
    ~doc:"The pool master host cannot be removed." ();
  error Api_errors.host_cannot_read_metrics []
    ~doc:"The metrics of this host could not be read." ();
  error Api_errors.host_in_use [ "host"; "type"; "ref" ]
    ~doc:"This operation cannot be completed as the host is in use by (at least) the object of type and ref echoed below." ();
  error Api_errors.host_not_disabled []
    ~doc:"This operation cannot be performed because the host is not disabled." ();
  error Api_errors.host_not_live []
    ~doc:"This operation cannot be completed as the host is not live." ();
  error Api_errors.host_is_live [ "host" ]
    ~doc:"This operation cannot be completed as the host is still live." ();

  error Api_errors.host_still_booting []
    ~doc:"The host is still booting." ();
  error Api_errors.host_has_no_management_ip []
    ~doc:"The host failed to acquire an IP address on its management interface and therefore cannot contact the master." ();
  error Api_errors.host_name_invalid [ "reason" ]
    ~doc:"The host name is invalid." ();
  error Api_errors.host_master_cannot_talk_back [ "ip" ]
    ~doc:"The master reports that it cannot talk back to the slave on the supplied management IP address." ();
  error Api_errors.host_unknown_to_master [ "host" ]
    ~doc:"The master says the host is not known to it. Perhaps the Host was deleted from the master's database?" ();
  error Api_errors.host_broken []
    ~doc:"This host failed in the middle of an automatic failover operation and needs to retry the failover action" ();
  error Api_errors.host_has_resident_vms [ "host" ]
    ~doc:"This host can not be forgotten because there are some user VMs still running" ();

  error Api_errors.not_supported_during_upgrade []
    ~doc:"This operation is not supported during an upgrade" ();

  error Api_errors.interface_has_no_ip [ "interface" ]
    ~doc:"The specified interface cannot be used because it has no IP address" ();
  error Api_errors.auth_already_enabled ["current auth_type";"current service_name"]
    ~doc:"External authentication for this host is already enabled." ();
  error Api_errors.auth_unknown_type ["type"]
    ~doc:"Unknown type of external authentication." ();
  error Api_errors.auth_is_disabled []
    ~doc:"External authentication is disabled, unable to resolve subject name." ();
  error Api_errors.auth_enable_failed ["message"]
    ~doc:"The host failed to enable external authentication." ();

  (* Pool errors *)
  error Api_errors.pool_joining_host_cannot_contain_shared_SRs []
    ~doc:"The host joining the pool cannot contain any shared storage." ();
  error Api_errors.pool_joining_host_cannot_have_running_or_suspended_VMs []
    ~doc:"The host joining the pool cannot have any running or suspended VMs." ();
  error Api_errors.pool_joining_host_cannot_have_running_VMs []
    ~doc:"The host joining the pool cannot have any running VMs." ();
  error Api_errors.pool_joining_host_cannot_have_vms_with_current_operations []
    ~doc:"The host joining the pool cannot have any VMs with active tasks." ();
  error Api_errors.pool_joining_host_cannot_be_master_of_other_hosts []
    ~doc:"The host joining the pool cannot already be a master of another pool." ();
  error Api_errors.pool_joining_host_connection_failed []
    ~doc:"There was an error connecting to the host while joining it in the pool." ();
  error Api_errors.pool_joining_host_service_failed []
    ~doc:"There was an error connecting to the host. the service contacted didn't reply properly." ();
  error Api_errors.pool_joining_host_must_have_physical_managment_nic []
    ~doc:"The host joining the pool must have a physical management NIC (i.e. the management NIC must not be on a VLAN or bonded PIF)." ();
  error Api_errors.pool_joining_external_auth_mismatch []
    ~doc:"Cannot join pool whose external authentication configuration is different." ();
  error Api_errors.pool_joining_host_must_have_same_product_version []
    ~doc:"The host joining the pool must have the same product version as the pool master." ();
  error Api_errors.pool_hosts_not_homogeneous [ "reason" ]
    ~doc:"The hosts in this pool are not homogeneous." ();
  error Api_errors.pool_not_in_emergency_mode []
    ~doc:"This pool is not in emergency mode." ();
  error Api_errors.pool_auth_already_enabled ["host"]
    ~doc:"External authentication in this pool is already enabled for at least one host." ();
  error Api_errors.pool_auth_enable_failed ["host";"message"]
    ~doc:"The pool failed to enable external authentication." ();
  error Api_errors.pool_auth_disable_failed ["host";"message"]
    ~doc:"The pool failed to disable the external authentication of at least one host." ();

  (* External directory service *)
  error Api_errors.subject_cannot_be_resolved []
    ~doc:"Subject cannot be resolved by the external directory service." ();
  error Api_errors.auth_service_error ["message"]
    ~doc:"Error querying the external directory service." ();
  error Api_errors.subject_already_exists []
    ~doc:"Subject already exists." ();

  (* RBAC *)
  error Api_errors.role_not_found []
    ~doc: "Role cannot be found." ();
  error Api_errors.role_already_exists []
    ~doc: "Role already exists." ();

  (* wlb errors*)
  error Api_errors.wlb_not_initialized []
    ~doc:"No WLB connection is configured." ();
  error Api_errors.wlb_disabled []
    ~doc:"This pool has wlb-enabled set to false." ();
  error Api_errors.wlb_connection_refused []
    ~doc:"The WLB server refused a connection to XenServer." ();
  error Api_errors.wlb_unknown_host []
    ~doc:"The configured WLB server name failed to resolve in DNS." ();
  error Api_errors.wlb_timeout ["configured_timeout"]
    ~doc:"The communication with the WLB server timed out." ();
  error Api_errors.wlb_authentication_failed []
    ~doc:"The WLB server rejected our configured authentication details." ();
  error Api_errors.wlb_malformed_request []
    ~doc:"The WLB server rejected XenServer's request as malformed." ();
  error Api_errors.wlb_malformed_response ["method"; "reason"; "response"]
    ~doc:"The WLB server said something that XenServer wasn't expecting or didn't understand.  The method called on the WLB server, a diagnostic reason, and the response from WLB are returned." ();
  error Api_errors.wlb_xenserver_connection_refused []
    ~doc:"The WLB server reported that XenServer refused it a connection (even though we're connecting perfectly fine in the other direction)." ();
  error Api_errors.wlb_xenserver_unknown_host []
    ~doc:"The WLB server reported that its configured server name for this XenServer instance failed to resolve in DNS." ();
  error Api_errors.wlb_xenserver_timeout []
    ~doc:"The WLB server reported that communication with XenServer timed out." ();
  error Api_errors.wlb_xenserver_authentication_failed []
    ~doc:"The WLB server reported that XenServer rejected its configured authentication details." ();
  error Api_errors.wlb_xenserver_malformed_response []
    ~doc:"The WLB server reported that XenServer said something to it that WLB wasn't expecting or didn't understand." ();
  error Api_errors.wlb_internal_error []
    ~doc:"The WLB server reported an internal error." ();
  error Api_errors.wlb_connection_reset []
    ~doc:"The connection to the WLB server was reset." ();
  error Api_errors.wlb_url_invalid ["url"]
    ~doc:"The WLB URL is invalid. Ensure it is in format: <ipaddress>:<port>.  The configured/given URL is returned." ();
    
  (* Api_errors specific to running VMs on multiple hosts *)
  error Api_errors.vm_unsafe_boot ["vm"]
    ~doc:"You attempted an operation on a VM that was judged to be unsafe by the server. This can happen if the VM would run on a CPU that has a potentially incompatible set of feature flags to those the VM requires. If you want to override this warning then use the 'force' option." ();
  error Api_errors.vm_requires_sr [ "vm"; "sr" ]
    ~doc:"You attempted to run a VM on a host which doesn't have access to an SR needed by the VM. The VM has at least one VBD attached to a VDI in the SR." ();
  error Api_errors.vm_requires_net [ "vm"; "network" ]
    ~doc:"You attempted to run a VM on a host which doesn't have a PIF on a Network needed by the VM. The VM has at least one VIF attached to the Network." ();
  error Api_errors.host_cannot_attach_network [ "host"; "network" ]
    ~doc:"Host cannot attach network (in the case of NIC bonding, this may be because attaching the network on this host would require other networks [that are currently active] to be taken down)." ();
  error Api_errors.vm_requires_vdi [ "vm"; "vdi" ]
    ~doc:"VM cannot be started because it requires a VDI which cannot be attached" ();
  error Api_errors.vm_migrate_failed [ "vm"; "source"; "destination"; "msg" ]
    ~doc:"An error occurred during the migration process." ();
  error Api_errors.vm_failed_shutdown_ack []
    ~doc:"VM didn't acknowledge the need to shutdown." ();
  error Api_errors.vm_shutdown_timeout [ "vm"; "timeout" ]
    ~doc:"VM failed to shutdown before the timeout expired" ();
  error Api_errors.bootloader_failed [ "vm"; "msg" ]
    ~doc:"The bootloader returned an error" ();
  error Api_errors.unknown_bootloader [ "vm"; "bootloader" ]
    ~doc:"The requested bootloader is unknown" ();
  error Api_errors.vms_failed_to_cooperate [ ]
    ~doc:"The given VMs failed to release memory when instructed to do so" ();


  (* Storage errors *)
  error Api_errors.sr_attach_failed ["sr"]
    ~doc:"Attaching this SR failed." ();
  error Api_errors.sr_backend_failure ["status"; "stdout"; "stderr"]
    ~doc:"There was an SR backend failure." ();
  error Api_errors.sr_uuid_exists ["uuid"]
    ~doc:"An SR with that uuid already exists." ();
  error Api_errors.sr_no_pbds ["sr"]
    ~doc:"The SR has no attached PBDs" ();
  error Api_errors.sr_full ["requested";"maximum"] 
    ~doc:"The SR is full. Requested new size exceeds the maximum size" ();
  error Api_errors.pbd_exists ["sr";"host";"pbd"]
    ~doc:"A PBD already exists connecting the SR to the host" ();
  error Api_errors.sr_has_pbd ["sr"] 
    ~doc:"The SR is still connected to a host via a PBD. It cannot be destroyed." ();
  error Api_errors.sr_has_multiple_pbds [ "PBD" ]
    ~doc:"The SR.shared flag cannot be set to false while the SR remains connected to multiple hosts" ();
  error Api_errors.sr_requires_upgrade [ "SR" ]
    ~doc:"The operation cannot be performed until the SR has been upgraded" ();
  error Api_errors.sr_unknown_driver [ "driver" ]
    ~doc:"The SR could not be connected because the driver was not recognised." ();
  error Api_errors.sr_vdi_locking_failed []
    ~doc:"The operation could not proceed because necessary VDIs were already locked at the storage level." ();
  error Api_errors.vdi_readonly [ "vdi" ]
    ~doc:"The operation required write access but this VDI is read-only" ();
  error Api_errors.vdi_is_a_physical_device [ "vdi" ]
    ~doc:"The operation cannot be performed on physical device" ();
  error Api_errors.vdi_is_not_iso [ "vdi"; "type" ]
    ~doc:"This operation can only be performed on CD VDIs (iso files or CDROM drives)" ();
  error Api_errors.vdi_in_use [ "vdi"; "operation" ]
    ~doc:"This operation cannot be performed because this VDI is in use by some other operation" ();
  error Api_errors.vdi_not_available [ "vdi" ]
    ~doc:"This operation cannot be performed because this VDI could not be properly attached to the VM." ();
  error Api_errors.vdi_location_missing [ "sr"; "location" ]
    ~doc:"This operation cannot be performed because the specified VDI could not be found in the specified SR" ();
  error Api_errors.vdi_missing [ "sr"; "vdi" ]
    ~doc:"This operation cannot be performed because the specified VDI could not be found on the storage substrate" ();
  error Api_errors.vdi_incompatible_type [ "vdi"; "type" ]
    ~doc:"This operation cannot be performed because the specified VDI is of an incompatible type (eg: an HA statefile cannot be attached to a guest)" ();
  error Api_errors.vdi_not_managed [ "vdi" ]
    ~doc:"This operation cannot be performed because the system does not manage this VDI" ();
  error Api_errors.cannot_create_state_file []
    ~doc:"An HA statefile could not be created, perhaps because no SR with the appropriate capability was found." ();

  error Api_errors.sr_operation_not_supported [ "sr" ]
    ~doc:"The SR backend does not support the operation (check the SR's allowed operations)" ();
  error Api_errors.sr_not_empty [ ]
    ~doc:"The SR operation cannot be performed because the SR is not empty." ();
  error Api_errors.sr_device_in_use [ ]
    ~doc:"The SR operation cannot be performed because a device underlying the SR is in use by the host." ();  
  error Api_errors.sr_not_sharable [ "sr"; "host" ]
    ~doc:"The PBD could not be plugged because the SR is in use by another host and is not marked as sharable." ();
  error Api_errors.sr_indestructible ["sr"]
    ~doc:"The SR could not be destroyed, as the 'indestructible' flag was set on it." ();
    
  error Api_errors.device_already_attached ["device"] 
    ~doc:"The device is already attached to a VM" ();
  error Api_errors.device_already_detached ["device"] 
    ~doc:"The device is not currently attached" ();
  error Api_errors.device_already_exists ["device"] 
    ~doc:"A device with the name given already exists on the selected VM" ();
  error Api_errors.invalid_device ["device"]
    ~doc:"The device name is invalid" ();

  error Api_errors.default_sr_not_found [ "sr" ]
    ~doc:"The default SR reference does not point to a valid SR" ();

  error Api_errors.only_provision_template [ ]
    ~doc:"The provision call can only be invoked on templates, not regular VMs." ();
  error Api_errors.provision_failed_out_of_space [ ]
    ~doc:"The provision call failed because it ran out of space." ();

  (* Import export errors *)
  error Api_errors.import_incompatible_version [ ]
    ~doc:"The import failed because this export has been created by a different (incompatible) product version" ();  
  error Api_errors.import_error_generic [ "msg" ]
    ~doc:"The VM could not be imported." ();
  error Api_errors.import_error_premature_eof []
    ~doc:"The VM could not be imported; the end of the file was reached prematurely." ();
  error Api_errors.import_error_some_checksums_failed []
    ~doc:"Some data checksums were incorrect; the VM may be corrupt." ();
  error Api_errors.import_error_cannot_handle_chunked []
    ~doc:"Cannot import VM using chunked encoding." ();
  error Api_errors.import_error_failed_to_find_object ["id"]
    ~doc:"The VM could not be imported because a required object could not be found." ();
  error Api_errors.import_error_attached_disks_not_found []
    ~doc:"The VM could not be imported because attached disks could not be found." ();
  error Api_errors.import_error_unexpected_file ["filename_expected";"filename_found"]
    ~doc:"The VM could not be imported because the XVA file is invalid: an unexpected file was encountered." ();

  (* Restore errors *)
  error Api_errors.restore_incompatible_version [ ]
    ~doc:"The restore could not be performed because this backup has been created by a different (incompatible) product version" ();  
  error Api_errors.restore_target_missing_device [ "device" ]
    ~doc:"The restore could not be performed because a network interface is missing" ();
  error Api_errors.restore_target_mgmt_if_not_in_backup [ ]
    ~doc:"The restore could not be performed because the host's current management interface is not in the backup. The interfaces mentioned in the backup are:" ();

  error Api_errors.cannot_find_state_partition [ ]
    ~doc:"This operation could not be performed because the state partition could not be found" ();
  error Api_errors.backup_script_failed [ "log" ]
    ~doc:"The backup could not be performed because the backup script failed." ();
  error Api_errors.restore_script_failed [ "log" ]
    ~doc:"The restore could not be performed because the restore script failed.  Is the file corrupt?" ();



  (* Event errors *)  
  error Api_errors.events_lost []
    ~doc:"Some events have been lost from the queue and cannot be retrieved." ();
  error Api_errors.session_not_registered ["handle"]
    ~doc:"This session is not registered to receive events.  You must call event.register before event.next.  The session handle you are using is echoed." ();

  error Api_errors.task_cancelled [ "task" ]
    ~doc:"The request was asynchronously cancelled." ();
  error Api_errors.too_many_pending_tasks [ ]
    ~doc:"The request was rejected because there are too many pending tasks on the server." ();
  error Api_errors.too_busy [ ]
    ~doc:"The request was rejected because the server is too busy." ();

  (* Patch errors *)
  error Api_errors.out_of_space ["location"]
    ~doc:"There is not enough space to upload the update" ();
  error Api_errors.invalid_patch []
    ~doc:"The uploaded patch file is invalid" ();
  error Api_errors.invalid_patch_with_log [ "log" ]
    ~doc:"The uploaded patch file is invalid.  See attached log for more details." ();
  error Api_errors.cannot_find_patch []
    ~doc:"The requested update could not be found.  This can occur when you designate a new master or xe patch-clean.  Please upload the update again" ();
  error Api_errors.cannot_fetch_patch ["uuid"]
    ~doc:"The requested update could to be obtained from the master." ();
  error Api_errors.patch_already_exists [ "uuid" ]
    ~doc:"The uploaded patch file already exists" ();
  error Api_errors.patch_is_applied [ ]
    ~doc:"The specified patch is applied and cannot be destroyed." ();
  error Api_errors.patch_already_applied [ "patch" ]
    ~doc:"This patch has already been applied" ();
  error Api_errors.patch_apply_failed [ "output" ]
    ~doc:"The patch apply failed.  Please see attached output." ();
  error Api_errors.patch_precheck_failed_unknown_error [ "patch"; "info" ]
    ~doc:"The patch precheck stage failed with an unknown error.  See attached info for more details." ();
  error Api_errors.patch_precheck_failed_prerequisite_missing [ "patch"; "prerequisite_patch_uuid_list" ]
    ~doc:"The patch precheck stage failed: prerequisite patches are missing." ();
  error Api_errors.patch_precheck_failed_wrong_server_version [ "patch"; "found_version"; "required_version"]
    ~doc:"The patch precheck stage failed: the server is of an incorrect version." ();
  error Api_errors.patch_precheck_failed_vm_running [ "patch" ]
    ~doc:"The patch precheck stage failed: there are one or more VMs still running on the server.  All VMs must be suspended before the patch can be applied." ();

  error Api_errors.cannot_find_oem_backup_partition []
    ~doc:"The backup partition to stream the updat to cannot be found" ();
  error Api_errors.only_allowed_on_oem_edition ["command"]
    ~doc:"This command is only allowed on the OEM edition." ();
  error Api_errors.not_allowed_on_oem_edition ["command"]
    ~doc:"This command is not allowed on the OEM edition." ();

  (* Pool errors *)

  error Api_errors.host_is_slave ["Master IP address"]
    ~doc:"You cannot make regular API calls directly on a slave. Please pass API calls via the master host." ();


  (* HA errors *)
  error Api_errors.ha_failed_to_form_liveset [ ]
    ~doc:"HA could not be enabled on the Pool because a liveset could not be formed: check storage and network heartbeat paths." ();
  error Api_errors.ha_heartbeat_daemon_startup_failed [ ]
    ~doc:"The host could not join the liveset because the HA daemon failed to start." ();
  error Api_errors.ha_host_cannot_access_statefile [ ]
    ~doc:"The host could not join the liveset because the HA daemon could not access the heartbeat disk." ();
  error Api_errors.ha_host_is_armed [ "host" ]
    ~doc:"The operation could not be performed while the host is still armed; it must be disarmed first" ();
  error Api_errors.ha_is_enabled [ ]
    ~doc:"The operation could not be performed because HA is enabled on the Pool" ();
  error Api_errors.ha_not_enabled [ ]
    ~doc:"The operation could not be performed because HA is not enabled on the Pool" ();
  error Api_errors.ha_not_installed [ "host" ]
    ~doc:"The operation could not be performed because the HA software is not installed on this host." ();
  error Api_errors.ha_host_cannot_see_peers [ "host"; "all"; "subset" ]
    ~doc:"The operation failed because the HA software on the specified host could not see a subset of other hosts. Check your network connectivity."
    ();
  error Api_errors.ha_too_few_hosts [ ]
    ~doc:"HA can only be enabled for 2 hosts or more. Note that 2 hosts requires a pre-configured quorum tiebreak script."
    ();
  error Api_errors.ha_should_be_fenced [ "host" ]
    ~doc:"Host cannot rejoin pool because it should have fenced (it is not in the master's partition)"
    ();
  error Api_errors.ha_abort_new_master [ "reason" ]
    ~doc:"This host cannot accept the proposed new master setting at this time."
    ();
  
  error Api_errors.ha_no_plan [ ]
    ~doc:"Cannot find a plan for placement of VMs as there are no other hosts available."
    ();
  error Api_errors.ha_lost_statefile [ ]
    ~doc:"This host lost access to the HA statefile."
    ();
  error Api_errors.ha_pool_is_enabled_but_host_is_disabled [ ]
    ~doc:"This host cannot join the pool because the pool has HA enabled but this host has HA disabled."
    ();
  error Api_errors.ha_constraint_violation_sr_not_shared [ "SR" ]
    ~doc:"This operation cannot be performed because the referenced SR is not properly shared. The SR must both be marked as shared and a currently_attached PBD must exist for each host."
    ();
  error Api_errors.ha_constraint_violation_network_not_shared [ "network" ]
    ~doc:"This operation cannot be performed because the referenced network is not properly shared. The network must either be entirely virtual or must be physically present via a currently_attached PIF on every host."
    ();

  error Api_errors.ha_operation_would_break_failover_plan [ ]
    ~doc:"This operation cannot be performed because it would invalidate VM failover planning such that the system would be unable to guarantee to restart protected VMs after a Host failure."
    ();
  error Api_errors.cannot_evacuate_host ["errors"]
    ~doc:"This host cannot be evacuated."
    ();

  error Api_errors.system_status_retrieval_failed ["reason"]
    ~doc:"Retrieving system status from the host failed.  A diagnostic reason suitable for support organisations is also returned."
    ();
  
  error Api_errors.system_status_must_use_tar_on_oem []
    ~doc:"You must use tar output to retrieve system status from an OEM host." ();

  error Api_errors.xapi_hook_failed ["hook_name"; "reason"; "stdout"; "exit_code"]
    ~doc:"3rd party xapi hook failed" ();

  error Api_errors.xenapi_missing_plugin ["name"]
    ~doc:"The requested plugin could not be found." ();
  error Api_errors.xenapi_plugin_failure ["status"; "stdout"; "stderr"]
    ~doc:"There was a failure communicating with the plugin." ();

  error Api_errors.domain_builder_error [ "function"; "code"; "message" ]
    ~doc:"An internal error generated by the domain builder." ();

  error Api_errors.certificate_does_not_exist ["name"]
    ~doc:"The specified certificate does not exist." ();
  error Api_errors.certificate_already_exists ["name"]
    ~doc:"A certificate already exists with the specified name." ();
  error Api_errors.certificate_name_invalid ["name"]
    ~doc:"The specified certificate name is invalid." ();
  error Api_errors.certificate_corrupt ["name"]
    ~doc:"The specified certificate is corrupt or unreadable." ();
  error Api_errors.certificate_library_corrupt []
    ~doc:"The certificate library is corrupt or unreadable." ();
  error Api_errors.crl_does_not_exist ["name"]
    ~doc:"The specified CRL does not exist." ();
  error Api_errors.crl_already_exists ["name"]
    ~doc:"A CRL already exists with the specified name." ();
  error Api_errors.crl_name_invalid ["name"]
    ~doc:"The specified CRL name is invalid." ();
  error Api_errors.crl_corrupt ["name"]
    ~doc:"The specified CRL is corrupt or unreadable." ();

  error Api_errors.ssl_verify_error ["reason"]
    ~doc:"The remote system's SSL certificate failed to verify against our certificate library." ();
	
  error Api_errors.cannot_enable_redo_log ["reason"] 
	~doc:"Could not enable redo log." ();

  error Api_errors.redo_log_is_enabled [] 
	~doc:"The operation could not be performed because a redo log is enabled on the Pool." ();
	
  ()


let _ =
  message Api_messages.ha_pool_overcommitted ~doc:"Pool has become overcommitted: it can nolonger guarantee to restart protected VMs if the configured number of hosts fail." ();
  message Api_messages.ha_statefile_lost ~doc:"Host lost access to HA storage heartbeat" ();
  message Api_messages.ha_heartbeat_approaching_timeout ~doc:"HA network heartbeat almost timed-out" ();
  message Api_messages.ha_statefile_approaching_timeout ~doc:"HA storage heartbeat almost timed-out" ();
  message Api_messages.ha_xapi_healthcheck_approaching_timeout ~doc:"HA xapi healthcheck almost timed-out" ();
  message Api_messages.ha_network_bonding_error ~doc:"HA network heartbeat interface bonding error" ();
  message Api_messages.vif_qos_failed ~doc:"Applying QoS to VIF failed." ();
  message Api_messages.vbd_qos_failed ~doc:"Applying QoS to VBD failed." ();
  message Api_messages.vcpu_qos_failed ~doc:"Applying QoS to VCPU failed." ();
  message Api_messages.pool_master_transition ~doc:"Host has become the new Pool master." ();
  message Api_messages.pbd_plug_failed_on_server_start ~doc:"Host failed to attach one or more Storage Repositories." ();
  ()

(* ------------------------------------------------------------------------------------------------------------
   Session Management
   ------------------------------------------------------------------------------------------------------------ *)

(* Session.Login *)

let session_login  = call ~flags:[]
  ~name:"login_with_password"
  ~in_product_since:rel_rio
  ~doc:"Attempt to authenticate the user, returning a session reference if successful"
  ~result:(Ref _session,"reference of newly created session")
  ~versioned_params:
  [{param_type=String; param_name="uname"; param_doc="Username for login."; param_release=rio_release; param_default=None};
   {param_type=String; param_name="pwd"; param_doc="Password for login."; param_release=rio_release; param_default=None};
   {param_type=String; param_name="version"; param_doc="Client API version."; param_release=miami_release; param_default=Some (VString "1.1")}]
  ~errs:[Api_errors.session_authentication_failed]
  ~secret:true
  ()

let slave_login  = call ~flags:[]
  ~name:"slave_login"
  ~doc:"Attempt to authenticate to the pool master by presenting the slave's host ref and pool secret"
  ~result:(Ref _session,"ID of newly created session")
  ~params:[
	    Ref _host, "host", "Host id of slave";
	    String, "psecret", "Pool secret"
	  ]
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~secret:true
  ~hide_from_docs:true
  ()

let slave_local_login = call ~flags:[]
  ~in_product_since:rel_miami
  ~name:"slave_local_login"
  ~doc:"Authenticate locally against a slave in emergency mode. Note the resulting sessions are only good for use on this host."
  ~result:(Ref _session,"ID of newly created session")
  ~params:[
	    String, "psecret", "Pool secret"
	  ]
  ~in_oss_since:None
  ~secret:true
  ~hide_from_docs:true
  ()

let slave_local_login_with_password = call ~flags:[]
  ~in_product_since:rel_miami
  ~name:"slave_local_login_with_password"
  ~doc:"Authenticate locally against a slave in emergency mode. Note the resulting sessions are only good for use on this host."
  ~result:(Ref _session,"ID of newly created session")
  ~params:[
	    String, "uname", "Username for login.";
            String, "pwd", "Password for login.";
	  ]
  ~in_oss_since:None
  ~secret:true
  ()

let local_logout = call ~flags:[`Session]
  ~in_product_since:rel_miami
  ~name:"local_logout"
  ~doc:"Log out of local session."
  ~params:[]
  ~in_oss_since:None
  ()

(* Session.Logout *)
  
let session_logout = call ~flags:[`Session]
  ~in_product_since:rel_rio
  ~name:"logout"
  ~doc:"Log out of a session"
  ~params:[]
  ()

let session_chpass = call ~flags:[`Session]
  ~name:"change_password"
  ~doc:"Change the account password; if your session is authenticated with root priviledges then the old_pwd is validated and the new_pwd is set regardless"
  ~params:[
	    String, "old_pwd", "Old password for account";
	    String, "new_pwd", "New password for account"
	  ]
  ~in_product_since:rel_rio
  ~in_oss_since:None
  ()

(* static function for class session *)
let session_get_all_subject_identifiers = call
  ~name:"get_all_subject_identifiers"
  ~doc:"Return a list of all the user subject-identifiers of all existing sessions"
  ~result:(Set (String), "The list of user subject-identifiers of all existing sessions")
  ~params:[]
  ~in_product_since:rel_george
  ~in_oss_since:None
  ()

(* static function for class session *)
let session_logout_subject_identifier = call
  ~name:"logout_subject_identifier"
  ~doc:"Log out all sessions associated to a user subject-identifier, except the session associated with the context calling this function"
  ~params:[
	    String, "subject_identifier", "User subject-identifier of the sessions to be destroyed"
	  ]
  ~in_product_since:rel_george
  ~in_oss_since:None
  ()

(* ------------------------------------------------------------------------------------------------------------
   Asynchronous Task Management
   ------------------------------------------------------------------------------------------------------------ *)

let cancel_result = Enum ("cancel_result",
			  [ "OK", "OK";
			    "Failed", "Not OK" ])

(* ------------------------------------------------------------------------------------------------------------
   RRD Consolidation function specification 
   ------------------------------------------------------------------------------------------------------------ *)

let rrd_cf_type = Enum ("rrd_cf_type",
		       [ "Average", "Average";
			 "Min", "Minimum";
			 "Max", "Maximum";
			 "Last", "Last value" ])


(* ------------------------------------------------------------------------------------------------------------
   VM Management
   ------------------------------------------------------------------------------------------------------------ *)

(* Install and UnInstall correspond to autogenerate create/delete functions *)

let vm_get_boot_record = call
  ~name:"get_boot_record"
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~doc:"Returns a record describing the VM's dynamic state, initialised when the VM boots and updated to reflect runtime configuration changes e.g. CPU hotplug"
  ~result:(Record _vm, "A record describing the VM")
  ~params:[Ref _vm, "self", "The VM whose boot-time state to return"]
  ~errs:[]
  ~flags:[`Session] (* no async *)
  ()

let vm_get_data_sources = call
  ~name:"get_data_sources"
  ~in_oss_since:None
  ~in_product_since:rel_orlando
  ~doc:""
  ~result:(Set (Record _data_source), "A set of data sources")
  ~params:[Ref _vm, "self", "The VM to interrogate"]
  ~errs:[]
  ~flags:[`Session] 
  ()

let vm_record_data_source = call
  ~name:"record_data_source"
  ~in_oss_since:None
  ~in_product_since:rel_orlando
  ~doc:"Start recording the specified data source"
  ~params:[Ref _vm, "self", "The VM";
	   String, "data_source", "The data source to record"]
  ~errs:[]
  ~flags:[`Session]
  ()

let vm_query_data_source = call
  ~name:"query_data_source"
  ~in_oss_since:None
  ~in_product_since:rel_orlando
  ~doc:"Query the latest value of the specified data source"
  ~params:[Ref _vm, "self", "The VM";
	   String, "data_source", "The data source to query"]
  ~result:(Float,"The latest value, averaged over the last 5 seconds")
  ~errs:[]
  ~flags:[`Session]
  ()

let vm_forget_data_source_archives = call
  ~name:"forget_data_source_archives"
  ~in_oss_since:None
  ~in_product_since:rel_orlando
  ~doc:"Forget the recorded statistics related to the specified data source"
  ~params:[Ref _vm, "self", "The VM";
	   String, "data_source", "The data source whose archives are to be forgotten"]
  ~flags:[`Session]
  ()

let vm_set_ha_always_run = call
  ~name:"set_ha_always_run"
  ~in_oss_since:None
  ~in_product_since:rel_orlando
  ~doc:"Set the value of the ha_always_run"
  ~params:[Ref _vm, "self", "The VM";
	   Bool, "value", "The value"]
  ~flags:[`Session]
  ()

let vm_set_ha_restart_priority = call
  ~name:"set_ha_restart_priority"
  ~in_oss_since:None
  ~in_product_since:rel_orlando
  ~doc:"Set the value of the ha_restart_priority field"
  ~params:[Ref _vm, "self", "The VM";
	   String, "value", "The value"]
  ~flags:[`Session]
  ()

(* VM.Clone *)

let vm_clone = call
  ~name:"clone"
  ~in_product_since:rel_rio
  ~doc:"Clones the specified VM, making a new VM. Clone automatically exploits the capabilities of the underlying storage repository in which the VM's disk images are stored (e.g. Copy on Write).   This function can only be called when the VM is in the Halted State."
  ~result:(Ref _vm, "The reference of the newly created VM.")
  ~params:[
	    Ref _vm, "vm", "The VM to be cloned";
	    String, "new_name", "The name of the cloned VM"
	  ]
  ~errs:[Api_errors.vm_bad_power_state; Api_errors.sr_full; Api_errors.operation_not_allowed]
  ()

(* VM.Copy *)
let vm_copy = call
  ~name:"copy"
  ~in_product_since:rel_rio
  ~doc:"Copied the specified VM, making a new VM. Unlike clone, copy does not exploits the capabilities of the underlying storage repository in which the VM's disk images are stored. Instead, copy guarantees that the disk images of the newly created VM will be 'full disks' - i.e. not part of a CoW chain.  This function can only be called when the VM is in the Halted State."
  ~result:(Ref _vm, "The reference of the newly created VM.")
  ~params:[
	    Ref _vm, "vm", "The VM to be copied";
	    String, "new_name", "The name of the copied VM";
	    Ref _sr, "sr", "An SR to copy all the VM's disks into (if an invalid reference then it uses the existing SRs)";
	  ]
  ~errs:[Api_errors.vm_bad_power_state; Api_errors.sr_full; Api_errors.operation_not_allowed]
  ()

(* VM.snapshot *)
let vm_snapshot_with_quiesce = call
  ~name:"snapshot_with_quiesce"
  ~in_product_since: rel_orlando
  ~doc:"Snapshots the specified VM with quiesce, making a new VM. Snapshot automatically exploits the capabilities of the underlying storage repository in which the VM's disk images are stored (e.g. Copy on Write)."
  ~result: (Ref _vm, "The reference of the newly created VM.")
  ~params:[
    Ref _vm, "vm", "The VM to be snapshotted";
    String, "new_name", "The name of the snapshotted VM"
  ]
  ~errs:[Api_errors.vm_bad_power_state; Api_errors.sr_full; Api_errors.operation_not_allowed;
		Api_errors.vm_snapshot_with_quiesce_failed;
		Api_errors.vm_snapshot_with_quiesce_timeout;
		Api_errors.vm_snapshot_with_quiesce_plugin_does_not_respond;
		Api_errors.vm_snapshot_with_quiesce_not_supported ]
  ()

let vm_update_snapshot_metadata = call
  ~name:"update_snapshot_metadata"
  ~in_product_since: rel_george
  ~doc:""
  ~hide_from_docs:true
  ~params:[
    Ref _vm, "vm", "The VM to update";
    Ref _vm, "snapshot_of", "";
    DateTime, "snapshot_time", "";
    String, "transportable_snapshot_id", "" ]
  ()

let vm_snapshot = call
  ~name:"snapshot"
  ~in_product_since: rel_orlando
  ~doc:"Snapshots the specified VM, making a new VM. Snapshot automatically exploits the capabilities of the underlying storage repository in which the VM's disk images are stored (e.g. Copy on Write)."
  ~result: (Ref _vm, "The reference of the newly created VM.")
  ~params:[
    Ref _vm, "vm", "The VM to be snapshotted";
    String, "new_name", "The name of the snapshotted VM"
  ]
  ~errs:[Api_errors.vm_bad_power_state; Api_errors.sr_full; Api_errors.operation_not_allowed]
  ()

let vm_revert = call
  ~name:"revert"
  ~in_product_since: rel_midnight_ride
  ~doc:"Reverts the specified VM to a previous state."
  ~params:[Ref _vm, "snapshot", "The snapshotted state that we revert to"]
  ~errs:[Api_errors.vm_bad_power_state; Api_errors.operation_not_allowed;
		Api_errors.sr_full; Api_errors.vm_revert_failed ]
  ()

let vm_checkpoint = call
  ~name:"checkpoint"
  ~in_product_since: rel_midnight_ride
  ~doc:"Checkpoints the specified VM, making a new VM. Checkppoint automatically exploits the capabilities of the underlying storage repository in which the VM's disk images are stored (e.g. Copy on Write) and saves the memory image as well."
  ~result: (Ref _vm, "The reference of the newly created VM.")
  ~params:[
    Ref _vm, "vm", "The VM to be checkpointed";
    String, "new_name", "The name of the checkpointed VM"
  ]
  ~errs:[Api_errors.vm_bad_power_state; Api_errors.sr_full; Api_errors.operation_not_allowed;
		Api_errors.vm_checkpoint_suspend_failed; Api_errors.vm_checkpoint_resume_failed]
  ()

let vm_create_template = call
  ~name:"create_template"
  ~in_product_since:rel_midnight_ride
  ~doc:"Creates a new template by cloning the specified VM. Clone automatically exploits the capabilities of the underlying storage repository in which the VM's disk images are stored (e.g. Copy on Write)."
  ~result:(Ref _vm, "The reference of the newly created template.")
  ~params:[
	    Ref _vm, "vm", "The VM to be cloned";
	    String, "new_name", "The name of the new template"
	  ]
  ~errs:[Api_errors.vm_bad_power_state; Api_errors.sr_full; Api_errors.operation_not_allowed]
  ()

(* VM.Provision -- causes the template's disks to be instantiated *)

let vm_provision = call
  ~name:"provision"
  ~doc:"Inspects the disk configuration contained within the VM's other_config, creates VDIs and VBDs and then executes any applicable post-install script."
  ~params:[
	    Ref _vm, "vm", "The VM to be provisioned";
	  ]
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~errs:[Api_errors.vm_bad_power_state; Api_errors.sr_full; Api_errors.operation_not_allowed]
  ()

(* VM.Start *)

let vm_start = call
  ~name:"start"
  ~in_product_since:rel_rio
  ~doc:"Start the specified VM.  This function can only be called with the VM is in the Halted State."
  ~params:[Ref _vm, "vm", "The VM to start";
           Bool, "start_paused", "Instantiate VM in paused state if set to true.";
	   Bool, "force", "Attempt to force the VM to start. If this flag is false then the VM may fail pre-boot safety checks (e.g. if the CPU the VM last booted on looks substantially different to the current one)";
	  ]
  ~errs:[Api_errors.vm_bad_power_state; Api_errors.vm_hvm_required; Api_errors.vm_is_template; Api_errors.other_operation_in_progress;
         Api_errors.operation_not_allowed;
	 Api_errors.bootloader_failed;
	 Api_errors.unknown_bootloader;
	 Api_errors.no_hosts_available;
	 Api_errors.license_restriction;
]
  ()

let vm_assert_can_boot_here = call
  ~name:"assert_can_boot_here"
  ~in_product_since:rel_rio
  ~doc:"Returns an error if the VM could not boot on this host for some reason"
  ~params:[Ref _vm, "self", "The VM";
	   Ref _host, "host", "The host"; ]
  ()
  ~errs:[Api_errors.host_not_enough_free_memory; Api_errors.vm_requires_sr]

let vm_assert_agile = call
  ~name:"assert_agile"
  ~in_product_since:rel_orlando
  ~doc:"Returns an error if the VM is not considered agile e.g. because it is tied to a resource local to a host"
  ~params:[Ref _vm, "self", "The VM"]
  ()

let vm_get_possible_hosts = call
  ~name:"get_possible_hosts"
  ~in_product_since:rel_rio
  ~doc:"Return the list of hosts on which this VM may run."
  ~params:[Ref _vm, "vm", "The VM" ]
  ~result:(Set (Ref _host), "The possible hosts")
  ()
  
let vm_retrieve_wlb_recommendations = call
  ~name:"retrieve_wlb_recommendations"
  ~in_product_since:rel_george
  ~doc:"Returns mapping of hosts to ratings, indicating the suitability of starting the VM at that location according to wlb. Rating is replaced with an error if the VM cannot boot there."
  ~params:[Ref _vm, "vm", "The VM";]
  ~result:(Map (Ref _host, Set(String)), "The potential hosts and their corresponding recommendations or errors")
  ()
  

let vm_maximise_memory = call
  ~in_product_since:rel_miami
  ~name:"maximise_memory"
  ~doc:"Returns the maximum amount of guest memory which will fit, together with overheads, in the supplied amount of physical memory. If 'exact' is true then an exact calculation is performed using the VM's current settings. If 'exact' is false then a more conservative approximation is used"
  ~params:[Ref _vm, "self", "The VM";
	   Int, "total", "Total amount of physical RAM to fit within";
	   Bool, "approximate", "If false the limit is calculated with the guest's current exact configuration. Otherwise a more approximate calculation is performed";
	  ]
  ~result:(Int, "The maximum possible static-max")
  ()

let vm_get_allowed_VBD_devices = call ~flags:[`Session] ~no_current_operations:true
  ~in_product_since:rel_rio
  ~name:"get_allowed_VBD_devices"
  ~doc:"Returns a list of the allowed values that a VBD device field can take"
  ~params:[Ref _vm,"vm","The VM to query"]
  ~result:(Set String, "The allowed values")
  ()

let vm_get_allowed_VIF_devices = call ~flags:[`Session] ~no_current_operations:true
  ~in_product_since:rel_rio
  ~name:"get_allowed_VIF_devices"
  ~doc:"Returns a list of the allowed values that a VIF device field can take"
  ~params:[Ref _vm,"vm","The VM to query"]
  ~result:(Set String, "The allowed values")
  ()

(* VM.atomic_set_resident_on *)
(* an internal call that sets resident_on and clears the scheduled_to_be_resident_on atomically *)

let vm_atomic_set_resident_on = call
  ~in_product_since:rel_rio
  ~pool_internal:true
  ~hide_from_docs:true
  ~name:"atomic_set_resident_on"
  ~doc:""
  ~params:[Ref _vm, "vm", "The VM to modify";
	   Ref _host, "host", "The host to set resident_on to"
          ]
  ()

let vm_compute_memory_overhead = call
	~in_product_since:rel_midnight_ride
	~name:"compute_memory_overhead"
	~doc:"Computes the virtualization memory overhead of a VM."
	~params:[Ref _vm, "vm", "The VM for which to compute the memory overhead"]
	~pool_internal:false
	~hide_from_docs:false
	~result:(Int, "the virtualization memory overhead of the VM.")
	()

let vm_set_memory_dynamic_max = call ~flags:[`Session]
	~in_product_since:rel_midnight_ride
	~name:"set_memory_dynamic_max"
	~doc:"Set the value of the memory_dynamic_max field"
	~params:[
		Ref _vm, "self", "The VM to modify";
		Int, "value", "The new value of memory_dynamic_max";
	]
	~errs:[] ()

let vm_set_memory_dynamic_min = call ~flags:[`Session]
	~in_product_since:rel_midnight_ride
	~name:"set_memory_dynamic_min"
	~doc:"Set the value of the memory_dynamic_min field"
	~params:[
		Ref _vm, "self", "The VM to modify";
		Int, "value", "The new value of memory_dynamic_min";
	]
	~errs:[] ()

let vm_set_memory_dynamic_range = call
	~name:"set_memory_dynamic_range"
	~in_product_since:rel_midnight_ride
	~doc:"Set the minimum and maximum amounts of physical memory the VM is \
		allowed to use."
	~params:[
		Ref _vm, "self", "The VM";
		Int, "min", "The new minimum value";
		Int, "max", "The new maximum value";
	] ()

(* When HA is enabled we need to prevent memory *)
(* changes which will break the recovery plan.  *)
let vm_set_memory_static_max = call ~flags:[`Session]
	~in_product_since:rel_orlando
	~name:"set_memory_static_max"
	~doc:"Set the value of the memory_static_max field"
	~errs:[Api_errors.ha_operation_would_break_failover_plan]
	~params:[
		Ref _vm, "self", "The VM to modify";
		Int, "value", "The new value of memory_static_max";
	] ()

let vm_set_memory_static_min = call ~flags:[`Session]
	~in_product_since:rel_midnight_ride
	~name:"set_memory_static_min"
	~doc:"Set the value of the memory_static_min field"
	~errs:[]
	~params:[
		Ref _vm, "self", "The VM to modify";
		Int, "value", "The new value of memory_static_min";
	] ()

let vm_set_memory_static_range = call
	~name:"set_memory_static_range"
	~in_product_since:rel_midnight_ride
	~doc:"Set the static (ie boot-time) range of virtual memory that the VM is \
		allowed to use."
	~params:[Ref _vm, "self", "The VM";
		Int, "min", "The new minimum value";
		Int, "max", "The new maximum value";
	] ()

let vm_set_memory_limits = call
	~name:"set_memory_limits"
	~in_product_since:rel_midnight_ride
	~doc:"Set the memory limits of this VM."
	~params:[Ref _vm, "self", "The VM";
		Int, "static_min", "The new value of memory_static_min.";
		Int, "static_max", "The new value of memory_static_max.";
		Int, "dynamic_min", "The new value of memory_dynamic_min.";
		Int, "dynamic_max", "The new value of memory_dynamic_max.";
	] ()

let vm_set_memory_target_live = call
	~name:"set_memory_target_live"
	~in_product_since:rel_rio
	~doc:"Set the memory target for a running VM"
	~params:[
		Ref _vm, "self", "The VM";
		Int, "target", "The target in bytes";
	] ()

let vm_wait_memory_target_live = call
	~name:"wait_memory_target_live"
	~in_product_since:rel_orlando
	~doc:"Wait for a running VM to reach its current memory target"
	~params:[
		Ref _vm, "self", "The VM";
	] ()

let vm_get_cooperative = call
  ~name:"get_cooperative"
  ~in_product_since:rel_midnight_ride
  ~doc:"Return true if the VM is currently 'co-operative' i.e. is expected to reach a balloon target and actually has done"
  ~params:[
    Ref _vm, "self", "The VM";
  ]
  ~result:(Bool, "true if the VM is currently 'co-operative'; false otherwise")
  ()

(* VM.StartOn *)

let vm_start_on = call
  ~in_product_since:rel_rio
  ~name:"start_on"
  ~doc:"Start the specified VM on a particular host.  This function can only be called with the VM is in the Halted State."
  ~in_oss_since:None
  ~params:[Ref _vm, "vm", "The VM to start";
	   Ref _host, "host", "The Host on which to start the VM";
           Bool, "start_paused", "Instantiate VM in paused state if set to true.";
	   Bool, "force", "Attempt to force the VM to start. If this flag is false then the VM may fail pre-boot safety checks (e.g. if the CPU the VM last booted on looks substantially different to the current one)";
	  ]
  ~errs:[Api_errors.vm_bad_power_state; Api_errors.vm_is_template; Api_errors.other_operation_in_progress;
         Api_errors.operation_not_allowed;
	 Api_errors.bootloader_failed;
	 Api_errors.unknown_bootloader;
]
  ()

(* VM.Pause *)

let vm_pause = call
  ~in_product_since:rel_rio
  ~name:"pause"
  ~doc:"Pause the specified VM. This can only be called when the specified VM is in the Running state."
  ~params:[Ref _vm, "vm", "The VM to pause"]
  ~errs:[Api_errors.vm_bad_power_state; Api_errors.other_operation_in_progress; Api_errors.operation_not_allowed;
         Api_errors.vm_is_template]
  ()  

(* VM.UnPause *)

let vm_unpause = call
  ~in_product_since:rel_rio
  ~name:"unpause"
  ~doc:"Resume the specified VM. This can only be called when the specified VM is in the Paused state."
  ~params:[Ref _vm, "vm", "The VM to unpause"]
  ~errs:[Api_errors.vm_bad_power_state; Api_errors.operation_not_allowed; Api_errors.vm_is_template]
  ()  


(* VM.CleanShutdown *)

let vm_cleanShutdown = call
  ~in_product_since:rel_rio
  ~name:"clean_shutdown"
  ~doc:"Attempt to cleanly shutdown the specified VM. (Note: this may not be supported---e.g. if a guest agent is not installed). This can only be called when the specified VM is in the Running state."
  ~params:[Ref _vm, "vm", "The VM to shutdown"]
  ~errs:[Api_errors.vm_bad_power_state; Api_errors.other_operation_in_progress; Api_errors.operation_not_allowed;
         Api_errors.vm_is_template]
  ()

(* VM.CleanReboot *)

let vm_cleanReboot = call
  ~in_product_since:rel_rio
  ~name:"clean_reboot"
  ~doc:"Attempt to cleanly shutdown the specified VM (Note: this may not be supported---e.g. if a guest agent is not installed). This can only be called when the specified VM is in the Running state."
  ~params:[Ref _vm, "vm", "The VM to shutdown"]
  ~errs:[Api_errors.vm_bad_power_state; Api_errors.other_operation_in_progress; Api_errors.operation_not_allowed;
         Api_errors.vm_is_template]
  ()

(* VM.HardShutdown *)

let vm_hardShutdown = call
  ~in_product_since:rel_rio
  ~name:"hard_shutdown"
  ~doc:"Stop executing the specified VM without attempting a clean shutdown."
  ~params:[Ref _vm, "vm", "The VM to destroy"]
  ~errs:[Api_errors.vm_bad_power_state; Api_errors.other_operation_in_progress; Api_errors.operation_not_allowed;
         Api_errors.vm_is_template]
  ()

(* VM.PowerStateReset *)

let vm_stateReset = call
  ~in_product_since:rel_rio
  ~name:"power_state_reset"
  ~doc:"Reset the power-state of the VM to halted in the database only. (Used to recover from slave failures in pooling scenarios by resetting the power-states of VMs running on dead slaves to halted.) This is a potentially dangerous operation; use with care."
  ~params:[Ref _vm, "vm", "The VM to reset"]
  ~errs:[]
  ()

(* VM.HardReboot *)

let vm_hardReboot = call
  ~in_product_since:rel_rio
  ~name:"hard_reboot"
  ~doc:"Stop executing the specified VM without attempting a clean shutdown and immediately restart the VM."
  ~params:[Ref _vm, "vm", "The VM to reboot"]
  ~errs:[Api_errors.vm_bad_power_state; Api_errors.other_operation_in_progress; Api_errors.operation_not_allowed;
         Api_errors.vm_is_template]
  ()

let vm_hardReboot_internal = call
  ~in_product_since:rel_orlando
  ~name:"hard_reboot_internal"
  ~doc:"Internal function which immediately restarts the specified VM."
  ~params:[Ref _vm, "vm", "The VM to reboot"]
  ~pool_internal:true
  ~hide_from_docs:true
  ()
  
(* VM.Hibernate *)
  
let vm_suspend = call
  ~in_product_since:rel_rio
  ~name:"suspend"
  ~doc:"Suspend the specified VM to disk.  This can only be called when the specified VM is in the Running state."
  ~params:[Ref _vm, "vm", "The VM to suspend"]
      (*	    Bool, "live", "If set to true, perform a live hibernate; otherwise suspend the VM before commencing hibernate" *)
  ~errs:[Api_errors.vm_bad_power_state; Api_errors.other_operation_in_progress; Api_errors.operation_not_allowed;
	 Api_errors.vm_is_template]
  ()

(* VM.clsp -- clone suspended, undocumented API for VMLogix *)
let csvm = call
  ~name:"csvm"
  ~in_product_since:rel_rio
  ~doc:"undocumented. internal use only. This call is deprecated."
  ~params:[Ref _vm, "vm", ""]
  ~result:(Ref _vm, "")
  ~errs:[]
  ~hide_from_docs:true
  ~internal_deprecated_since:rel_miami
  ()
      
(* VM.UnHibernate *)
      
let vm_resume = call
  ~name:"resume"
  ~in_product_since:rel_rio
  ~doc:"Awaken the specified VM and resume it.  This can only be called when the specified VM is in the Suspended state."
  ~params:[Ref _vm, "vm", "The VM to resume";
           Bool, "start_paused", "Resume VM in paused state if set to true.";
	   Bool, "force", "Attempt to force the VM to resume. If this flag is false then the VM may fail pre-resume safety checks (e.g. if the CPU the VM was running on looks substantially different to the current one)";
]
  ~errs:[Api_errors.vm_bad_power_state; Api_errors.operation_not_allowed; Api_errors.vm_is_template]
  ()

let vm_resume_on = call
  ~name:"resume_on"
  ~in_product_since:rel_rio
  ~doc:"Awaken the specified VM and resume it on a particular Host.  This can only be called when the specified VM is in the Suspended state."
  ~in_oss_since:None
  ~params:[Ref _vm, "vm", "The VM to resume";
	   Ref _host, "host", "The Host on which to resume the VM";
           Bool, "start_paused", "Resume VM in paused state if set to true.";
	   Bool, "force", "Attempt to force the VM to resume. If this flag is false then the VM may fail pre-resume safety checks (e.g. if the CPU the VM was running on looks substantially different to the current one)";
]
  ~errs:[Api_errors.vm_bad_power_state; Api_errors.operation_not_allowed; Api_errors.vm_is_template]
  ()

let vm_pool_migrate = call
  ~in_oss_since:None 
  ~in_product_since:rel_rio
  ~name:"pool_migrate"
  ~doc:"Migrate a VM to another Host. This can only be called when the specified VM is in the Running state."
  ~params:[Ref _vm, "vm", "The VM to migrate";
	   Ref _host, "host", "The target host";
	   Map(String, String), "options", "Extra configuration operations" ]
  ~errs:[Api_errors.vm_bad_power_state; Api_errors.other_operation_in_progress; Api_errors.vm_is_template; Api_errors.operation_not_allowed; Api_errors.vm_migrate_failed; Api_errors.vm_missing_pv_drivers]
  ()

let set_vcpus_number_live = call
	~name:"set_VCPUs_number_live"
	~in_product_since:rel_rio
	~doc:"Set the number of VCPUs for a running VM"
	~params:[Ref _vm, "self", "The VM";
		Int, "nvcpu", "The number of VCPUs"]
	()

let vm_set_VCPUs_max = call ~flags:[`Session]
	~name:"set_VCPUs_max"
	~in_product_since:rel_midnight_ride
	~doc:"Set the maximum number of VCPUs for a halted VM"
	~params:[Ref _vm, "self", "The VM";
		Int, "value", "The new maximum number of VCPUs"]
	()

let vm_set_VCPUs_at_startup = call ~flags:[`Session]
	~name:"set_VCPUs_at_startup"
	~in_product_since:rel_midnight_ride
	~doc:"Set the number of startup VCPUs for a halted VM"
	~params:[Ref _vm, "self", "The VM";
		Int, "value", "The new maximum number of VCPUs"]
	()

let vm_set_HVM_shadow_multiplier = call ~flags:[`Session]
	~name:"set_HVM_shadow_multiplier"
	~in_product_since:rel_midnight_ride
	~doc:"Set the shadow memory multiplier on a halted VM"
	~params:[Ref _vm, "self", "The VM";
		Float, "value", "The new shadow memory multiplier to set"]
	()

let vm_set_shadow_multiplier_live = call
	~name:"set_shadow_multiplier_live"
	~in_product_since:rel_rio
	~doc:"Set the shadow memory multiplier on a running VM"
	~params:[Ref _vm, "self", "The VM";
		Float, "multiplier", "The new shadow memory multiplier to set"]
	()

let vm_add_to_VCPUs_params_live = call
  ~name:"add_to_VCPUs_params_live"
  ~in_product_since:rel_rio
  ~doc:"Add the given key-value pair to VM.VCPUs_params, and apply that value on the running VM"
  ~params:[Ref _vm, "self", "The VM";
           String, "key", "The key";
           String, "value", "The value"]
  ()

let vm_send_sysrq = call
  ~name:"send_sysrq"
  ~in_product_since:rel_rio
  ~doc:"Send the given key as a sysrq to this VM.  The key is specified as a single character (a String of length 1).  This can only be called when the specified VM is in the Running state."
  ~params:[Ref _vm, "vm", "The VM";
           String, "key", "The key to send"]
  ~errs:[Api_errors.vm_bad_power_state]
  ()

let vm_send_trigger = call
  ~name:"send_trigger"
  ~in_product_since:rel_rio
  ~doc:"Send the named trigger to this VM.  This can only be called when the specified VM is in the Running state."
  ~params:[Ref _vm, "vm", "The VM";
           String, "trigger", "The trigger to send"]
  ~errs:[Api_errors.vm_bad_power_state]
  ()

let vm_migrate = call
  ~name: "migrate"
  ~in_product_since:rel_rio
  ~doc: "Migrate the VM to another host.  This can only be called when the specified VM is in the Running state."
  ~params:[Ref _vm, "vm", "The VM";
           String, "dest", "The destination host";
           Bool, "live", "Live migration";
           Map (String, String), "options", "Other parameters"]
  ~errs:[Api_errors.vm_bad_power_state]
  ~hide_from_docs:true
  ()

let vm_create_new_blob = call
  ~name: "create_new_blob"
  ~in_product_since:rel_orlando
  ~doc:"Create a placeholder for a named binary blob of data that is associated with this VM"
  ~params:[Ref _vm, "vm", "The VM";
	   String, "name", "The name associated with the blob";
	   String, "mime_type", "The mime type for the data. Empty string translates to application/octet-stream";]
  ~result:(Ref _blob, "The reference of the blob, needed for populating its data")
  ()

(* ------------------------------------------------------------------------------------------------------------
   Host Management
   ------------------------------------------------------------------------------------------------------------ *)

let host_ha_disable_failover_decisions = call
  ~in_product_since:rel_orlando
  ~name:"ha_disable_failover_decisions"
  ~doc:"Prevents future failover decisions happening on this node. This function should only be used as part of a controlled shutdown of the HA system."
  ~params:[Ref _host, "host", "The Host to disable failover decisions for"]
  ~pool_internal:true
  ~hide_from_docs:true
  ()

let host_ha_disarm_fencing = call
  ~in_product_since:rel_orlando
  ~name:"ha_disarm_fencing"
  ~doc:"Disarms the fencing function of the HA subsystem. This function is extremely dangerous and should only be used as part of a controlled shutdown of the HA system."
  ~params:[Ref _host, "host", "The Host to disarm"]
  ~pool_internal:true
  ~hide_from_docs:true
  ()

let host_ha_stop_daemon = call
  ~in_product_since:rel_orlando
  ~name:"ha_stop_daemon"
  ~doc:"Stops the HA daemon. This function is extremely dangerous and should only be used as part of a controlled shutdown of the HA system."
  ~params:[Ref _host, "host", "The Host whose daemon should be stopped"]
  ~pool_internal:true
  ~hide_from_docs:true
  ()

let host_ha_release_resources = call
  ~in_product_since:rel_orlando
  ~name:"ha_release_resources"
  ~doc:"Cleans up any resources on the host associated with this HA instance."
  ~params:[Ref _host, "host", "The Host whose resources should be cleaned up"]
  ~pool_internal:true
  ~hide_from_docs:true
  ()


let host_local_assert_healthy = call ~flags:[`Session]
  ~in_product_since:rel_miami
  ~name:"local_assert_healthy"
  ~doc:"Returns nothing if this host is healthy, otherwise it throws an error explaining why the host is unhealthy"
  ~params:[]
  ~pool_internal:true
  ~hide_from_docs:true
  ~errs:[ Api_errors.host_still_booting;
	  Api_errors.host_has_no_management_ip;
	  Api_errors.host_master_cannot_talk_back;
	  Api_errors.host_unknown_to_master;
	  Api_errors.host_broken;
	  Api_errors.license_restriction;
	  Api_errors.license_does_not_support_pooling;
	  Api_errors.ha_should_be_fenced;
	]
  ()

let host_preconfigure_ha = call
  ~in_product_since:rel_miami
  ~name:"preconfigure_ha"  
  ~doc:"Attach statefiles, generate config files but do not start the xHA daemon."
  ~params:[Ref _host, "host", "The Host to modify";
	   Set(Ref _vdi), "statefiles", "Set of statefile VDIs to use";
	   Ref _vdi, "metadata_vdi", "VDI to use for Pool metadata";
	   String, "generation", "UUID identifying this HA instance";
	  ]
  ~pool_internal:true
  ~hide_from_docs:true
  ()  

let host_ha_join_liveset = call
  ~in_product_since:rel_orlando
  ~name:"ha_join_liveset"
  ~doc:"Block until this host joins the liveset."
  ~params:[Ref _host, "host", "The Host whose HA datmon to start"]
  ~pool_internal:true
  ~hide_from_docs:true
  ()

let host_ha_wait_for_shutdown_via_statefile = call
  ~in_product_since:rel_orlando
  ~name:"ha_wait_for_shutdown_via_statefile"
  ~doc:"Block until this host xHA daemon exits after having seen the invalid statefile. If the host loses statefile access then throw an exception"
  ~params:[Ref _host, "host", "The Host whose HA subsystem to query"]
  ~pool_internal:true
  ~hide_from_docs:true
  ()

let host_query_ha = call ~flags:[`Session]
  ~in_product_since:rel_miami
  ~name:"query_ha"
  ~doc:"Return the local HA configuration as seen by this host"
  ~params:[]
  ~custom_marshaller:true  
  ~pool_internal:true
  ~hide_from_docs:true
  ()

let host_request_backup = call ~flags:[`Session]
  ~name:"request_backup"
  ~in_product_since:rel_rio
  ~doc:"Request this host performs a database backup"
  ~params:[Ref _host, "host", "The Host to send the request to";
	   Int, "generation", "The generation count of the master's database";
	   Bool, "force", "If this is true then the client _has_ to take a backup, otherwise it's just an 'offer'"
	  ]
  ~pool_internal:true
  ~hide_from_docs:true
  ()

let host_request_config_file_sync = call ~flags:[`Session]
  ~name:"request_config_file_sync"
  ~in_product_since:rel_rio
  ~doc:"Request this host syncs dom0 config files"
  ~params:[Ref _host, "host", "The Host to send the request to";
	   String, "hash", "The hash of the master's dom0 config files package"
	  ]
  ~pool_internal:true
  ~hide_from_docs:true
  ()


(* Since there are no async versions, no tasks are generated (!) this is important
   otherwise the call would block doing a Db.Task.create *)
let host_propose_new_master = call ~flags:[`Session]
  ~in_product_since:rel_miami
  ~name:"propose_new_master"
  ~doc:"First phase of a two-phase commit protocol to set the new master. If the host has already committed to another configuration or if the proposed new master is not in this node's membership set then the call will return an exception."
  ~params:[String, "address", "The address of the Host which is proposed as the new master";
	   Bool, "manual", "True if this call is being invoked by the user manually, false if automatic";
	  ]
  ~pool_internal:true
  ~hide_from_docs:true
  ()

let host_abort_new_master = call ~flags:[`Session]
  ~in_product_since:rel_miami
  ~name:"abort_new_master"
  ~doc:"Causes the new master transaction to abort"
  ~params:[String, "address", "The address of the Host which is proposed as the new master"]
  ~pool_internal:true
  ~hide_from_docs:true
  ()  

let host_commit_new_master = call ~flags:[`Session]
  ~in_product_since:rel_miami
  ~name:"commit_new_master"
  ~doc:"Second phase of a two-phase commit protocol to set the new master."
  ~params:[String, "address", "The address of the Host which should be committed as the new master"]
  ~pool_internal:true
  ~hide_from_docs:true
  ()

let host_compute_free_memory = call
	~in_product_since:rel_orlando
	~name:"compute_free_memory"
	~doc:"Computes the amount of free memory on the host."
	~params:[Ref _host, "host", "The host to send the request to"]
	~pool_internal:false
	~hide_from_docs:false
	~result:(Int, "the amount of free memory on the host.")
	()

let host_compute_memory_overhead = call
	~in_product_since:rel_midnight_ride
	~name:"compute_memory_overhead"
	~doc:"Computes the virtualization memory overhead of a host."
	~params:[Ref _host, "host", "The host for which to compute the memory overhead"]
	~pool_internal:false
	~hide_from_docs:false
	~result:(Int, "the virtualization memory overhead of the host.")
	()

(* Diagnostics see if host is in emergency mode *)
let host_is_in_emergency_mode = call ~flags:[`Session]
  ~in_product_since:rel_miami
  ~name:"is_in_emergency_mode"
  ~doc:"Diagnostics call to discover if host is in emergency mode"
  ~params:[]
  ~pool_internal:false
  ~hide_from_docs:true
  ~result:(Bool, "true if host is in emergency mode")
  ()

(* Signal that the management IP address or hostname has been changed beneath us. *)
let host_signal_networking_change = call ~flags:[`Session]
  ~in_product_since:rel_miami
  ~name:"signal_networking_change"
  ~doc:"Signals that the management IP address or hostname has been changed beneath us."
  ~pool_internal:true
  ~hide_from_docs:true
  ()

let host_notify = call
  ~in_product_since:rel_miami
  ~name:"notify"
  ~doc:"Notify an event"
  ~params:[String, "ty", "type of the notification";
           String, "params", "arguments of the notification (can be empty)"; ]
  ~pool_internal:true
  ~hide_from_docs:true
  ()

let host_syslog_reconfigure = call
  ~in_product_since:rel_miami
  ~name:"syslog_reconfigure"
  ~doc:"Re-configure syslog logging"
  ~params:[Ref _host, "host", "Tell the host to reread its Host.logging parameters and reconfigure itself accordingly"]
  ()

let host_management_reconfigure = call
  ~in_product_since:rel_miami
  ~name:"management_reconfigure"
  ~doc:"Reconfigure the management network interface"
  ~params:[
    Ref _pif, "pif", "reference to a PIF object corresponding to the management interface";
	  ]
  ()

let host_local_management_reconfigure = call ~flags:[`Session]
  ~in_product_since:rel_miami
  ~name:"local_management_reconfigure"
  ~doc:"Reconfigure the management network interface. Should only be used if Host.management_reconfigure is impossible because the network configuration is broken."
  ~params:[
    String, "interface", "name of the interface to use as a management interface";
	  ]
  ()

let host_ha_xapi_healthcheck = call ~flags:[`Session]
  ~in_product_since:rel_orlando
  ~name:"ha_xapi_healthcheck"
  ~doc:"Returns true if xapi appears to be functioning normally."
  ~result:(Bool, "true if xapi is functioning normally.")
  ~hide_from_docs:true
  ()

let host_management_disable = call ~flags:[`Session]
  ~in_product_since:rel_miami
  ~name:"management_disable"
  ~doc:"Disable the management network interface"
  ~params:[]
  ()

(* Simple host evacuate message for Miami.
   Not intended for HA *)

let host_assert_can_evacuate = call
  ~in_product_since:rel_miami
  ~name:"assert_can_evacuate"
  ~doc:"Check this host can be evacuated."
  ~params:[Ref _host, "host", "The host to evacuate"]
  ()

(* New Orlando message which aims to make the GUI less brittle (unexpected errors will trigger a VM suspend)
   and sensitive to HA planning constraints *)
let host_get_vms_which_prevent_evacuation = call
  ~in_product_since:rel_orlando
  ~name:"get_vms_which_prevent_evacuation"
  ~doc:"Return a set of VMs which prevent the host being evacuated, with per-VM error codes"
  ~params:[Ref _host, "self", "The host to query"]
  ~result:(Map(Ref _vm, Set(String)), "VMs which block evacuation together with reasons")
  ()

let host_evacuate = call
  ~in_product_since:rel_miami
  ~name:"evacuate"
  ~doc:"Migrate all VMs off of this host, where possible."
  ~params:[Ref _host, "host", "The host to evacuate"]
  ()
  
let host_get_uncooperative_resident_VMs = call
  ~in_product_since:rel_midnight_ride
  ~name:"get_uncooperative_resident_VMs"
  ~doc:"Return a set of VMs which are not co-operating with the host's memory control system"
  ~params:[Ref _host, "self", "The host to query"]
  ~result:((Set(Ref _vm)), "VMs which are not co-operating")
  ()

let host_get_uncooperative_domains = call
  ~in_product_since:rel_midnight_ride
  ~name:"get_uncooperative_domains"
  ~doc:"Return the set of domain uuids which are not co-operating with the host's memory control system"
  ~params:[Ref _host, "self", "The host to query"]
  ~result:((Set(String)), "UUIDs of domains which are not co-operating")
  ~pool_internal:true
  ~hide_from_docs:true
  ()

let host_retrieve_wlb_evacuate_recommendations = call
  ~name:"retrieve_wlb_evacuate_recommendations"
  ~in_product_since:rel_george
  ~doc:"Retrieves recommended host migrations to perform when evacuating the host from the wlb server. If a VM cannot be migrated from the host the reason is listed instead of a recommendation."
  ~params:[Ref _host, "self", "The host to query"]
  ~result:(Map(Ref _vm, Set(String)), "VMs and the reasons why they would block evacuation, or their target host recommended by the wlb server")
  ()

(* Host.Disable *)

let host_disable = call
  ~in_product_since:rel_rio
  ~name:"disable"
  ~doc:"Puts the host into a state in which no new VMs can be started. Currently active VMs on the host continue to execute."
  ~params:[Ref _host, "host", "The Host to disable"]
  ()

(* Host.Enable *)

let host_enable = call
  ~name:"enable"
  ~in_product_since:rel_rio
  ~doc:"Puts the host into a state in which new VMs can be started."
  ~params:[Ref _host, "host", "The Host to enable"]
  ()

(* Host.Shutdown *)

let host_shutdown = call
  ~name:"shutdown"
  ~in_product_since:rel_rio
  ~doc:"Shutdown the host. (This function can only be called if there are no currently running VMs on the host and it is disabled.)"
  ~params:[Ref _host, "host", "The Host to shutdown"]
  ()

(* Host.reboot *)

let host_reboot = call
  ~name:"reboot"
  ~in_product_since:rel_rio
  ~doc:"Reboot the host. (This function can only be called if there are no currently running VMs on the host and it is disabled.)"
  ~params:[Ref _host, "host", "The Host to reboot"]
  ()

(* Host.power_on *)

let host_power_on = call
  ~name:"power_on"
  ~in_product_since:rel_orlando
  ~doc:"Attempt to power-on the host (if the capability exists)."
  ~params:[Ref _host, "host", "The Host to power on"]
  ()

let host_restart_agent = call
  ~name:"restart_agent"
  ~in_product_since:rel_rio
  ~doc:"Restarts the agent after a 10 second pause. WARNING: this is a dangerous operation. Any operations in progress will be aborted, and unrecoverable data loss may occur. The caller is responsible for ensuring that there are no operations in progress when this method is called."
  ~params:[Ref _host, "host", "The Host on which you want to restart the agent"]
  ()

let host_shutdown_agent = call
  ~name:"shutdown_agent"
  ~in_product_since:rel_orlando
  ~doc:"Shuts the agent down after a 10 second pause. WARNING: this is a dangerous operation. Any operations in progress will be aborted, and unrecoverable data loss may occur. The caller is responsible for ensuring that there are no operations in progress when this method is called."
  ~params:[]
  ~flags:[`Session] (* no async *)
  ()

let host_dmesg = call
  ~name:"dmesg"
  ~in_product_since:rel_rio
  ~doc:"Get the host xen dmesg."
  ~params:[Ref _host, "host", "The Host to query"]
  ~result:(String, "dmesg string")
  ()

let host_dmesg_clear = call
  ~name:"dmesg_clear"
  ~in_product_since:rel_rio
  ~doc:"Get the host xen dmesg, and clear the buffer."
  ~params:[Ref _host, "host", "The Host to query"]
  ~result:(String, "dmesg string")
  ()

let host_get_log = call
  ~name:"get_log"
  ~in_product_since:rel_rio
  ~doc:"Get the host's log file"
  ~params:[Ref _host, "host", "The Host to query"]
  ~result:(String, "The contents of the host's primary log file")
  ()

let host_send_debug_keys = call
  ~name:"send_debug_keys"
  ~in_product_since:rel_rio
  ~doc:"Inject the given string as debugging keys into Xen"
  ~params:[Ref _host, "host", "The host";
           String, "keys", "The keys to send"]
  ()

let host_get_data_sources = call
  ~name:"get_data_sources"
  ~in_oss_since:None
  ~in_product_since:rel_orlando
  ~doc:""
  ~result:(Set (Record _data_source), "A set of data sources")
  ~params:[Ref _host, "host", "The host to interrogate"]
  ~errs:[]
  ~flags:[`Session] 
  ()

let host_record_data_source = call
  ~name:"record_data_source"
  ~in_oss_since:None
  ~in_product_since:rel_orlando
  ~doc:"Start recording the specified data source"
  ~params:[Ref _host, "host", "The host";
	   String, "data_source", "The data source to record"]
  ~errs:[]
  ~flags:[`Session]
  ()

let host_query_data_source = call
  ~name:"query_data_source"
  ~in_oss_since:None
  ~in_product_since:rel_orlando
  ~doc:"Query the latest value of the specified data source"
  ~params:[Ref _host, "host", "The host";
	   String, "data_source", "The data source to query"]
  ~result:(Float,"The latest value, averaged over the last 5 seconds")
  ~errs:[]
  ~flags:[`Session]
  ()

let host_attach_static_vdis = call
  ~name:"attach_static_vdis"
	~in_product_since:rel_midnight_ride
  ~doc:"Statically attach VDIs on a host."
  ~params:[Ref _host, "host", "The Host to modify";
    Map(Ref _vdi, String), "vdi_reason_map", "List of VDI+reason pairs to attach"
	  ]
  ~pool_internal:true
  ~hide_from_docs:true
  () 

let host_detach_static_vdis = call
  ~name:"detach_static_vdis"
	~in_product_since:rel_midnight_ride
  ~doc:"Detach static VDIs from a host."
  ~params:[Ref _host, "host", "The Host to modify";
	   Set(Ref _vdi), "vdis", "Set of VDIs to detach";
	  ]
  ~pool_internal:true
  ~hide_from_docs:true
  ()

let host_forget_data_source_archives = call
  ~name:"forget_data_source_archives"
  ~in_oss_since:None
  ~in_product_since:rel_orlando
  ~doc:"Forget the recorded statistics related to the specified data source"
  ~params:[Ref _host, "host", "The host";
	   String, "data_source", "The data source whose archives are to be forgotten"]
  ~flags:[`Session]
  ()

let host_get_diagnostic_timing_stats = call ~flags:[`Session]
  ~in_product_since:rel_miami
  ~name:"get_diagnostic_timing_stats"
  ~doc:"Return timing statistics for diagnostic purposes"
  ~params:[Ref _host, "host", "The host to interrogate"]
  ~result:(Map(String, String), "population name to summary map")
  ~hide_from_docs:true
  ()

let host_create_new_blob = call
  ~name: "create_new_blob"
  ~in_product_since:rel_orlando
  ~doc:"Create a placeholder for a named binary blob of data that is associated with this host"
  ~params:[Ref _host, "host", "The host";
	   String, "name", "The name associated with the blob";
	   String, "mime_type", "The mime type for the data. Empty string translates to application/octet-stream";]
  ~result:(Ref _blob, "The reference of the blob, needed for populating its data")
  ()

let host_call_plugin = call
  ~name:"call_plugin"
  ~in_product_since:rel_orlando
  ~doc:"Call a XenAPI plugin on this host"
  ~params:[Ref _host, "host", "The host";
	   String, "plugin", "The name of the plugin";
	   String, "fn", "The name of the function within the plugin";
	   Map(String, String), "args", "Arguments for the function";]
  ~result:(String, "Result from the plugin")
  ()

let host_enable_binary_storage = call
  ~name:"enable_binary_storage"
  ~in_product_since:rel_orlando
  ~hide_from_docs:true
  ~pool_internal:true
  ~doc:"Enable binary storage on a particular host, for storing RRDs, messages and blobs"
  ~params:[Ref _host, "host", "The host"]
  ()

let host_disable_binary_storage = call
  ~name:"disable_binary_storage"
  ~in_product_since:rel_orlando
  ~hide_from_docs:true
  ~pool_internal:true
  ~doc:"Disable binary storage on a particular host, deleting stored RRDs, messages and blobs"
  ~params:[Ref _host, "host", "The host"]
  ()

let host_update_pool_secret = call
	~name:"update_pool_secret"
	~in_product_since:rel_midnight_ride
	~hide_from_docs:true
	~pool_internal:true
	~doc:""
	~params:[
		Ref _host, "host", "The host";
		String, "pool_secret", "The new pool secret" ]
	()

let host_update_master = call
	~name:"update_master"
	~in_product_since:rel_midnight_ride
	~hide_from_docs:true
	~pool_internal:true
	~doc:""
	~params:[
		Ref _host, "host", "The host";
		String, "master_address", "The new master address" ]
	()

let host_set_localdb_key = call
  ~name:"set_localdb_key"
	~in_product_since:rel_midnight_ride
  ~doc:"Set a key in the local DB of the host."
  ~params:[Ref _host, "host", "The Host to modify";
    String, "key", "Key to change";
    String, "value", "Value to set"
	  ]
  ~pool_internal:true
  ~hide_from_docs:true
  () 

(* ------------------------------------------------------------------------------------------------------------
   VDI Management
   ------------------------------------------------------------------------------------------------------------ *)

(* VDI.Snapshot *)

let vdi_snapshot = call
  ~name:"snapshot"
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~versioned_params:
  [{param_type=Ref _vdi; param_name="vdi"; param_doc="The VDI to snapshot"; param_release=rio_release; param_default=None};
   {param_type=Map (String, String); param_name="driver_params"; param_doc="Optional parameters that can be passed through to backend driver in order to specify storage-type-specific snapshot options"; param_release=miami_release; param_default=Some (VMap [])}
  ]
  ~doc:"Take a read-only snapshot of the VDI, returning a reference to the snapshot. If any driver_params are specified then these are passed through to the storage-specific substrate driver that takes the snapshot. NB the snapshot lives in the same Storage Repository as its parent."
  ~result:(Ref _vdi, "The ID of the newly created VDI.")
  ()

let vdi_clone = call
  ~name:"clone"
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~params:[Ref _vdi, "vdi", "The VDI to clone"]
  ~versioned_params:
  [{param_type=Ref _vdi; param_name="vdi"; param_doc="The VDI to clone"; param_release=rio_release; param_default=None};
   {param_type=Map (String, String); param_name="driver_params"; param_doc="Optional parameters that are passed through to the backend driver in order to specify storage-type-specific clone options"; param_release=miami_release; param_default=Some (VMap [])}
  ]
  ~doc:"Take an exact copy of the VDI and return a reference to the new disk. If any driver_params are specified then these are passed through to the storage-specific substrate driver that implements the clone operation. NB the clone lives in the same Storage Repository as its parent."
  ~result:(Ref _vdi, "The ID of the newly created VDI.")
  ()

let vdi_resize = call
  ~name:"resize"
  ~in_product_since:rel_rio
  ~in_oss_since:None
  ~params:[Ref _vdi, "vdi", "The VDI to resize"; Int, "size", "The new size of the VDI" ]
  ~doc:"Resize the VDI."
  ()

let vdi_resize_online = call
  ~name:"resize_online"
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~params:[Ref _vdi, "vdi", "The VDI to resize"; Int, "size", "The new size of the VDI" ]
  ~doc:"Resize the VDI which may or may not be attached to running guests."
  ()

let vdi_copy = call
  ~name:"copy"
  ~in_product_since:rel_rio
  ~in_oss_since:None
  ~params:[Ref _vdi, "vdi", "The VDI to copy"; Ref _sr, "sr", "The destination SR" ]
  ~doc:"Make a fresh VDI in the specified SR and copy the supplied VDI's data to the new disk"
  ~result:(Ref _vdi, "The reference of the newly created VDI.")
  ()

(* ------------------------------------------------------------------------------------------------------------
   VBDs
   ------------------------------------------------------------------------------------------------------------ *)

let vbd_eject = call
  ~name:"eject"
  ~in_product_since:rel_rio
  ~doc:"Remove the media from the device and leave it empty"
  ~params:[Ref _vbd, "vbd", "The vbd representing the CDROM-like device"]
  ~errs:[Api_errors.vbd_not_removable_media; Api_errors.vbd_is_empty]
  ()

let vbd_insert = call
  ~name:"insert"
  ~in_product_since:rel_rio
  ~doc:"Insert new media into the device"
  ~params:[Ref _vbd, "vbd", "The vbd representing the CDROM-like device";
	   Ref _vdi, "vdi", "The new VDI to 'insert'"]
  ~errs:[Api_errors.vbd_not_removable_media; Api_errors.vbd_not_empty]
  ()

let vbd_plug = call
  ~name:"plug"
  ~in_product_since:rel_rio
  ~doc:"Hotplug the specified VBD, dynamically attaching it to the running VM"
  ~params:[Ref _vbd, "self", "The VBD to hotplug"]
  ()

let vbd_unplug = call
  ~name:"unplug"
  ~in_product_since:rel_rio
  ~doc:"Hot-unplug the specified VBD, dynamically unattaching it from the running VM"
  ~params:[Ref _vbd, "self", "The VBD to hot-unplug"]
  ~errs:[Api_errors.device_detach_rejected; Api_errors.device_already_detached]
  ()
 
let vbd_unplug_force = call
  ~name:"unplug_force"
  ~in_product_since:rel_rio
  ~doc:"Forcibly unplug the specified VBD"
  ~params:[Ref _vbd, "self", "The VBD to forcibly unplug"]
  ()

let vbd_unplug_force_no_safety_check = call
  ~name:"unplug_force_no_safety_check"
  ~doc:"Forcibly unplug the specified VBD without any safety checks. This is an extremely dangerous operation in the general case that can cause guest crashes and data corruption; it should be called with extreme caution."
  ~params:[Ref _vbd, "self", "The VBD to forcibly unplug (no safety checks are applied to test if the device supports surprise-remove)"]
  ~hide_from_docs:true
  ~in_product_since:rel_symc
  ()

let vbd_pause = call
  ~name:"pause"
  ~doc:"Stop the backend device servicing requests so that an operation can be performed on the disk (eg live resize, snapshot)"
  ~params:[Ref _vbd, "self", "The VBD to pause"]
  ~hide_from_docs:true
  ~in_product_since:rel_symc
  ~result:(String, "Token to uniquely identify this pause instance, used to match the corresponding unpause") (* new in MR *)
  ()

let vbd_unpause = call
  ~name:"unpause"
  ~doc:"Restart the backend device after it was paused while an operation was performed on the disk (eg live resize, snapshot)"
  ~versioned_params:
  [{param_type=Ref _vbd; param_name="self"; param_doc="The VBD to unpause"; param_release=miami_symc_release; param_default=None};
   {param_type=String; param_name="token"; param_doc="The token from VBD.pause"; param_release=orlando_release; param_default=Some(VString "")}]
  ~hide_from_docs:true
  ~in_product_since:rel_symc
  ()

let vbd_assert_attachable = call
  ~name:"assert_attachable"
  ~in_product_since:rel_rio
  ~doc:"Throws an error if this VBD could not be attached to this VM if the VM were running. Intended for debugging."
  ~params:[Ref _vbd, "self", "The VBD to query"]
  ~in_oss_since:None
  ()

(******************************************************************************************************************)
(* Now define the objects themselves and their fields *)


(** Make an object field record *)
let field ?(in_oss_since = Some "3.0.3") ?(in_product_since = rel_rio) ?(internal_only = false)
    ?internal_deprecated_since ?(ignore_foreign_key = false)
    ?(qualifier = RW) ?(ty = String) ?(effect = false) ?(default_value = None) ?(persist = true) name desc =
  

  Field { release={internal=get_product_releases in_product_since; 
		   opensource=(get_oss_releases in_oss_since);
		   internal_deprecated_since=internal_deprecated_since;};
	  qualifier=qualifier; ty=ty; internal_only = internal_only; default_value = default_value;
	  field_name=name; 
	  full_name=[ name ];
	  field_description=desc;
	  field_persist=persist;
	  field_has_effect = effect;
	  field_ignore_foreign_key = ignore_foreign_key }

let uid ?(in_oss_since=Some "3.0.3") refname = field ~in_oss_since ~qualifier:DynamicRO ~ty:(String) "uuid" "unique identifier/object reference"

let allowed_and_current_operations operations_type =
  [ 
    field ~persist:false ~in_oss_since:None ~qualifier:DynamicRO ~ty:(Set operations_type) "allowed_operations" "list of the operations allowed in this state. This list is advisory only and the server state may have changed by the time this field is read by a client.";
    field ~persist:false ~in_oss_since:None ~qualifier:DynamicRO ~ty:(Map(String, operations_type)) "current_operations" "links each of the running tasks using this object (by reference) to a current_operation enum which describes the nature of the task.";
  ]


(** Make a Namespace (note effect on enclosing field.full_names) *)
let namespace ~name ~contents = 
  let rec prefix = function
    | Namespace(x, xs) -> Namespace(x, List.map prefix xs)
    | Field x -> Field { x with full_name = name :: x.full_name } in
  Namespace(name, List.map prefix contents)

(** Create an object and map the object name into the messages *)
let create_obj ~in_oss_since ~in_product_since ~internal_deprecated_since ~gen_constructor_destructor ?force_custom_actions:(force_custom_actions=false) ~gen_events ~persist ~name ~descr ~doccomments ~contents ~messages ~in_db () =
    let msgs = List.map (fun m -> {m with msg_obj_name=name}) messages in
    { name = name; description = descr; messages = msgs; contents = contents;
      doccomments = doccomments; gen_constructor_destructor = gen_constructor_destructor; force_custom_actions = force_custom_actions;
      persist = persist; gen_events = gen_events; obj_release = {internal=get_product_releases in_product_since; opensource=get_oss_releases in_oss_since; internal_deprecated_since = internal_deprecated_since};
      in_database=in_db;
    }

(** Additional messages for srs *)
let dev_config_param =
  {param_type=Map(String,String); param_name="device_config"; param_doc="The device config string that will be passed to backend SR driver"; param_release=rio_release; param_default=None}

let sr_host_param =
  {param_type=Ref _host; param_name="host"; param_doc="The host to create/make the SR on"; param_release=rio_release; param_default=None}

let sr_physical_size_param =
  {param_type=Int; param_name="physical_size"; param_doc="The physical size of the new storage repository"; param_release=rio_release; param_default=None}

let sr_shared_param =
  {param_type=Bool; param_name="shared"; param_doc="True if the SR (is capable of) being shared by multiple hosts"; param_release=rio_release; param_default=None}

let sr_create_common =
  [
    {param_type=String; param_name="name_label"; param_doc="The name of the new storage repository"; param_release=rio_release; param_default=None};
    {param_type=String; param_name="name_description"; param_doc="The description of the new storage repository"; param_release=rio_release; param_default=None};
    {param_type=String; param_name="type"; param_doc="The type of the SR; used to specify the SR backend driver to use"; param_release=rio_release; param_default=None};
    {param_type=String; param_name="content_type"; param_doc="The type of the new SRs content, if required (e.g. ISOs)"; param_release=rio_release; param_default=None};
  ]

let sr_sm_config = 
  {param_type=Map(String,String); param_name="sm_config"; param_doc="Storage backend specific configuration options"; param_release=miami_release; param_default=Some (VMap [])}


let sr_create = call
  ~name:"create"
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~versioned_params:(sr_host_param::dev_config_param::sr_physical_size_param::(sr_create_common @  [ sr_shared_param; sr_sm_config ] ))
  ~doc:"Create a new Storage Repository and introduce it into the managed system, creating both SR record and PBD record to attach it to current host (with specified device_config parameters)"
  ~result:(Ref _sr, "The reference of the newly created Storage Repository.")
  ~errs:[Api_errors.sr_unknown_driver]
    ()

let destroy_self_param =
  (Ref _sr, "sr", "The SR to destroy")

let sr_destroy = call
  ~name:"destroy"
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~doc:"Destroy specified SR, removing SR-record from database and remove SR from disk. (In order to affect this operation the appropriate device_config is read from the specified SR's PBD on current host)"
  ~errs:[Api_errors.sr_has_pbd]
  ~params:[destroy_self_param]
  ()

let sr_forget = call
  ~name:"forget"
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~doc:"Removing specified SR-record from database, without attempting to remove SR from disk"
  ~params:[destroy_self_param]
  ~errs:[Api_errors.sr_has_pbd]
  ()

let sr_introduce = 
  call
  ~name:"introduce"
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~versioned_params:({param_type=String; param_name="uuid"; param_doc="The uuid assigned to the introduced SR"; param_release=rio_release; param_default=None}::(sr_create_common @ [sr_shared_param; sr_sm_config]))
  ~doc:"Introduce a new Storage Repository into the managed system"
  ~result:(Ref _sr, "The reference of the newly introduced Storage Repository.")
    ()

let sr_probe = call
  ~name:"probe"
  ~in_oss_since:None
  ~in_product_since:rel_miami
  ~versioned_params:[sr_host_param; dev_config_param; {param_type=String; param_name="type"; param_doc="The type of the SR; used to specify the SR backend driver to use"; param_release=miami_release; param_default=None}; sr_sm_config]
  ~doc:"Perform a backend-specific scan, using the given device_config.  If the device_config is complete, then this will return a list of the SRs present of this type on the device, if any.  If the device_config is partial, then a backend-specific scan will be performed, returning results that will guide the user in improving the device_config."
  ~result:(String, "An XML fragment containing the scan results.  These are specific to the scan being performed, and the backend.")
    ()

let sr_make = call
  ~name:"make"
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~internal_deprecated_since:rel_miami
  ~versioned_params:(sr_host_param::dev_config_param::sr_physical_size_param::(sr_create_common @ [sr_sm_config]))
  ~doc:"Create a new Storage Repository on disk. This call is deprecated: use SR.create instead."
  ~result:(String, "The uuid of the newly created Storage Repository.")
    ()

let sr_get_supported_types = call
  ~name:"get_supported_types"
  ~in_product_since:rel_rio
  ~flags:[`Session]
  ~doc:"Return a set of all the SR types supported by the system"
  ~params:[]
  ~result:(Set String, "the supported SR types")
()

let sr_scan = call
  ~name:"scan"
  ~in_product_since:rel_rio
  ~doc:"Refreshes the list of VDIs associated with an SR"
  ~params:[Ref _sr, "sr", "The SR to scan" ]
  ()

(* Nb, although this is a new explicit call, it's actually been in the API since rio - just autogenerated. So no setting of rel_miami. *)
let sr_set_shared = call
  ~name:"set_shared"
  ~in_product_since:rel_rio
  ~doc:"Sets the shared flag on the SR"
  ~params:[Ref _sr, "sr", "The SR";
	   Bool, "value", "True if the SR is shared"]
  ()

let sr_create_new_blob = call
  ~name: "create_new_blob"
  ~in_product_since:rel_orlando
  ~doc:"Create a placeholder for a named binary blob of data that is associated with this SR"
  ~params:[Ref _sr, "sr", "The SR";
	   String, "name", "The name associated with the blob";
	   String, "mime_type", "The mime type for the data. Empty string translates to application/octet-stream";]
  ~result:(Ref _blob, "The reference of the blob, needed for populating its data")
  ()

let pbd_plug = call
  ~name:"plug"
  ~in_oss_since:None 
  ~in_product_since:rel_rio
  ~doc:"Activate the specified PBD, causing the referenced SR to be attached and scanned"
  ~params:[Ref _pbd, "self", "The PBD to activate"]
  ~errs:[Api_errors.sr_unknown_driver]
  ()

let pbd_unplug = call
  ~name:"unplug"
  ~in_oss_since:None 
  ~in_product_since:rel_rio
  ~doc:"Deactivate the specified PBD, causing the referenced SR to be detached and nolonger scanned"
  ~params:[Ref _pbd, "self", "The PBD to deactivate"]
  ()

(** Sessions *)
let session = 
    create_obj ~in_db:true ~in_product_since:rel_rio ~in_oss_since:oss_since_303 ~internal_deprecated_since:None ~persist:PersistNothing ~gen_constructor_destructor:false ~name:_session ~descr:"A session" ~gen_events:false
    ~doccomments:[]
    ~messages:[session_login; session_logout; session_chpass;
	       slave_login; 
	       slave_local_login; slave_local_login_with_password; local_logout;
	       session_get_all_subject_identifiers; session_logout_subject_identifier;
	      ] ~contents:[
		  uid _session; 
		  field ~qualifier:DynamicRO ~ty:(Ref _host)
		    "this_host" "Currently connected host";
		  field ~qualifier:DynamicRO ~ty:(Ref _user) 
		    "this_user" "Currently connected user";
		  field ~qualifier:DynamicRO ~ty:DateTime
		    "last_active" "Timestamp for last time session was active";
		  field ~qualifier:DynamicRO ~ty:Bool ~in_oss_since:None
		    "pool" "True if this session relates to a intra-pool login, false otherwise";
		  field ~in_product_since:rel_miami ~default_value:(Some (VMap [])) ~ty:(Map(String, String)) "other_config" "additional configuration";
		  field ~in_product_since:rel_george ~qualifier:DynamicRO ~default_value:(Some (VBool false)) ~ty:Bool "is_local_superuser" "true iff this session was created using local superuser credentials";
		  field ~in_product_since:rel_george ~qualifier:DynamicRO ~default_value:(Some (VRef (Ref.string_of Ref.null))) ~ty:(Ref _subject) "subject" "references the subject instance that created the session. If a session instance has is_local_superuser set, then the value of this field is undefined.";
		  field ~in_product_since:rel_george ~qualifier:DynamicRO ~default_value:(Some(VDateTime(Date.of_float 0.))) ~ty:DateTime "validation_time" "time when session was last validated";
		  field ~in_product_since:rel_george ~qualifier:DynamicRO ~default_value:(Some(VString(""))) ~ty:String "auth_user_sid" "the subject identifier of the user that was externally authenticated. If a session instance has is_local_superuser set, then the value of this field is undefined.";
		]
	()

(** Many of the objects have a set of names of various lengths: *)
let names in_oss_since qual =
  let field x y = field x y ~in_oss_since ~qualifier:qual in
    [ field "label" "a human-readable name";
      field "description" "a notes field containg human-readable description" ]


(** Tasks *)


(* NB: the status 'cancelling' is not being used, nor should it ever be used. It should be purged from here! *)
let status_type = Enum("task_status_type", [ "pending", "task is in progress";
					     "success", "task was completed successfully";
					     "failure", "task has failed";
					     "cancelling", "task is being cancelled";
					     "cancelled", "task has been cancelled" ])


let task_cancel = call
  
  ~name:"cancel"
  ~in_product_since:rel_rio
  ~doc:"Request that a task be cancelled. Note that a task may fail to be cancelled and may complete or fail normally and note that, even when a task does cancel, it might take an arbitrary amount of time."
  ~params:[Ref _task, "task", "The task"]
  ~errs:[Api_errors.operation_not_allowed]
  ()


let task_create = call ~flags:[`Session]
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~name:"create"
  ~doc:"Create a new task object which must be manually destroyed."
  ~params:[String, "label", "short label for the new task";
	   String, "description", "longer description for the new task"]
  ~result:(Ref _task, "The reference of the created task object")
  ()

let task_destroy = call ~flags:[`Session]
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~name:"destroy"
  ~doc:"Destroy the task object"
  ~params:[Ref _task, "self", "Reference to the task object"]
  ()

let task_allowed_operations =
  Enum ("task_allowed_operations", List.map operation_enum [ task_cancel ])

let task = 
  create_obj ~in_db:true ~in_product_since:rel_rio ~in_oss_since:oss_since_303 ~internal_deprecated_since:None ~persist:PersistNothing ~gen_constructor_destructor:false ~name:_task ~descr:"A long-running asynchronous task" ~gen_events:true
    ~doccomments:[] 
    ~messages: [ task_create; task_destroy; task_cancel ] 
    ~contents: ([
      uid _task;
      namespace ~name:"name" ~contents:(names oss_since_303 DynamicRO);
    ] @ (allowed_and_current_operations task_allowed_operations) @ [
      field ~qualifier:DynamicRO ~ty:DateTime "created" "Time task was created";
      field ~qualifier:DynamicRO ~ty:DateTime "finished" "Time task finished (i.e. succeeded or failed). If task-status is pending, then the value of this field has no meaning";
      field  ~qualifier:DynamicRO ~ty:status_type "status" "current status of the task";
      field ~in_oss_since:None ~internal_only:true ~qualifier:DynamicRO ~ty:(Ref _session) "session" "the session that created the task";
      field  ~qualifier:DynamicRO ~ty:(Ref _host) "resident_on" "the host on which the task is running";
      field  ~qualifier:DynamicRO ~ty:Float "progress" "if the task is still pending, this field contains the estimated fraction complete (0.-1.). If task has completed (successfully or unsuccessfully) this should be 1.";
      field ~in_oss_since:None ~internal_only:true ~qualifier:DynamicRO ~ty:Int "externalpid" "If the task has spawned a program, the field record the PID of the process that the task is waiting on. (-1 if no waiting completion of an external program )";
      field ~in_oss_since:None ~internal_only:true ~qualifier:DynamicRO ~ty:Int "stunnelpid" "If the task has been forwarded, this field records the pid of the stunnel process spawned to manage the forwarding connection";
      field ~in_oss_since:None ~internal_only:true ~qualifier:DynamicRO ~ty:Bool "forwarded" "True if this task has been forwarded to a slave";
      field ~in_oss_since:None ~internal_only:true ~qualifier:DynamicRO ~ty:(Ref _host) "forwarded_to" "The host to which the task has been forwarded";
      field  ~qualifier:DynamicRO ~ty:String "type" "if the task has completed successfully, this field contains the type of the encoded result (i.e. name of the class whose reference is in the result field). Undefined otherwise.";
      field  ~qualifier:DynamicRO ~ty:String "result" "if the task has completed successfully, this field contains the result value (either Void or an object reference). Undefined otherwise.";
      field  ~qualifier:DynamicRO ~ty:(Set String) "error_info" "if the task has failed, this field contains the set of associated error strings. Undefined otherwise.";
      field ~in_product_since:rel_miami ~default_value:(Some (VMap [])) ~ty:(Map(String, String)) "other_config" "additional configuration";
      (* field ~ty:(Set(Ref _alert)) ~in_product_since:rel_miami ~qualifier:DynamicRO "alerts" "all alerts related to this task"; *)
      field ~qualifier:DynamicRO ~in_product_since:rel_orlando ~default_value:(Some (VRef "")) ~ty:(Ref _task) "subtask_of" "Ref pointing to the task this is a substask of.";
      field ~qualifier:DynamicRO ~in_product_since:rel_orlando ~ty:(Set (Ref _task)) "subtasks"   "List pointing to all the substasks."; 
    ]) 
    ()

(** Many of the objects need to record IO bandwidth *)
let iobandwidth =
  [ field ~persist:false ~qualifier:DynamicRO ~ty:Float "read_kbs" "Read bandwidth (KiB/s)";
    field ~persist:false ~qualifier:DynamicRO ~ty:Float "write_kbs" "Write bandwidth (KiB/s)" ]

(** Human users *)
let user =
  create_obj ~in_db:true ~in_product_since:rel_rio ~in_oss_since:oss_since_303 ~internal_deprecated_since:None ~persist:PersistEverything ~gen_constructor_destructor:true ~name:_user ~descr:"A user of the system" ~gen_events:false
    ~doccomments:[] 
    ~messages:[] ~contents:
      [ uid _user;
	field ~qualifier:StaticRO "short_name" "short name (e.g. userid)";
	field "fullname" "full name";
	  field ~in_product_since:rel_orlando ~default_value:(Some (VMap [])) ~ty:(Map(String, String)) "other_config" "additional configuration";
      ]
    ()

(** Guest Memory *)
let guest_memory =
	let field = field ~ty:Int in
	[
		field "overhead" ~qualifier:DynamicRO "Virtualization memory overhead (bytes)." ~default_value:(Some (VInt 0L));
		field "target" ~qualifier:StaticRO "Dynamically-set memory target (bytes). The value of this field indicates the current target for memory available to this VM." ~default_value:(Some (VInt 0L));
		field "static_max" ~qualifier:StaticRO "Statically-set (i.e. absolute) maximum (bytes). The value of this field at VM start time acts as a hard limit of the amount of memory a guest can use. New values only take effect on reboot.";
		field "dynamic_max" ~qualifier:StaticRO "Dynamic maximum (bytes)";
		field "dynamic_min" ~qualifier:StaticRO "Dynamic minimum (bytes)";
		field "static_min" ~qualifier:StaticRO "Statically-set (i.e. absolute) mininum (bytes). The value of this field indicates the least amount of memory this VM can boot with without crashing.";
	]

(** Host Memory *)
let host_memory = 
	let field = field ~ty:Int in
	[
		field ~qualifier:DynamicRO "overhead" "Virtualization memory overhead (bytes)." ~default_value:(Some (VInt 0L));
	]

(** Host Metrics Memory *)
let host_metrics_memory = 
	let field = field ~ty:Int in
	[
		field ~qualifier:DynamicRO "total" "Host's total memory (bytes)";
		field ~qualifier:DynamicRO "free" "Host's free memory (bytes)";
	]

let api_version = 
  let field' = field ~qualifier:DynamicRO in
  [
    field' ~ty:Int "major" "major version number";
    field' ~ty:Int "minor" "minor version number";
    field' ~ty:String "vendor" "identification of vendor";
    field' ~ty:(Map(String,String)) "vendor_implementation" "details of vendor implementation";
  ]

(* Management of host crash dumps. Note that this would be neater if crashes were stored in 
   VDIs like VM crashes, however the nature of a host crash dump is that the dom0 has crashed
   and has no access to any fancy storage drivers or tools. Plus a host is not guaranteed to 
   have any SRs at all. *)

let host_crashdump_destroy = call
  ~name:"destroy"
  ~doc:"Destroy specified host crash dump, removing it from the disk."
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~params:[ Ref _host_crashdump, "self", "The host crashdump to destroy" ]
  ()

let host_crashdump_upload = call
  ~name:"upload"
  ~doc:"Upload the specified host crash dump to a specified URL"
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~params:[ Ref _host_crashdump, "self", "The host crashdump to upload";
	    String, "url", "The URL to upload to";
	    Map(String, String), "options", "Extra configuration operations" ]
  ()

let host_crashdump =
  create_obj ~in_db:true ~in_product_since:rel_rio ~in_oss_since:None ~internal_deprecated_since:None ~persist:PersistEverything ~gen_constructor_destructor:false ~name:_host_crashdump ~gen_events:true
    ~descr:"Represents a host crash dump"
    ~doccomments:[]
    ~messages: [host_crashdump_destroy; host_crashdump_upload]
    ~contents:
    [ uid ~in_oss_since:None _host_crashdump;
      field ~in_oss_since:None ~qualifier:StaticRO ~ty:(Ref _host) "host" "Host the crashdump relates to";
      field ~in_oss_since:None ~qualifier:DynamicRO ~ty:DateTime "timestamp" "Time the crash happened";
      field ~in_oss_since:None ~qualifier:DynamicRO ~ty:Int "size" "Size of the crashdump";
      field ~qualifier:StaticRO ~ty:String ~in_oss_since:None ~internal_only:true "filename" "filename of crash dir";
      field ~in_product_since:rel_miami ~default_value:(Some (VMap [])) ~ty:(Map(String, String)) "other_config" "additional configuration";
    ] 
    ()

(* New Miami pool patching mechanism *)

let pool_patch_after_apply_guidance =
  Enum ("after_apply_guidance", 
        [ "restartHVM",  "This patch requires HVM guests to be restarted once applied.";
          "restartPV",   "This patch requires PV guests to be restarted once applied.";
		  "restartHost", "This patch requires the host to be restarted once applied."; 
          "restartXAPI", "This patch requires XAPI to be restarted once applied.";
        ])

let pool_patch_apply = call
  ~name:"apply"
  ~doc:"Apply the selected patch to a host and return its output"
  ~in_oss_since:None
  ~in_product_since:rel_miami
  ~params:[ Ref _pool_patch, "self", "The patch to apply"; Ref _host, "host", "The host to apply the patch too" ]  
  ~result:(String, "the output of the patch application process")
  ()

let pool_patch_precheck = call
  ~name:"precheck"
  ~doc:"Execute the precheck stage of the selected patch on a host and return its output"
  ~in_oss_since:None
  ~in_product_since:rel_miami
  ~params:[ Ref _pool_patch, "self", "The patch whose prechecks will be run"; Ref _host, "host", "The host to run the prechecks on" ]  
  ~result:(String, "the output of the patch prechecks")
  ()

let pool_patch_clean = call
  ~name:"clean"
  ~doc:"Removes the patch's files from all hosts in the pool, but does not remove the database entries"
  ~in_oss_since:None
  ~in_product_since:rel_miami
  ~params:[ Ref _pool_patch, "self", "The patch to clean up" ]
  ()

let pool_patch_destroy = call
  ~name:"destroy"
  ~doc:"Removes the patch's files from all hosts in the pool, and removes the database entries.  Only works on unapplied patches."
  ~in_oss_since:None
  ~in_product_since:rel_miami
  ~params:[ Ref _pool_patch, "self", "The patch to destroy" ]
  ()

let pool_patch_pool_apply = call
  ~name:"pool_apply"
  ~doc:"Apply the selected patch to all hosts in the pool and return a map of host_ref -> patch output"
  ~in_oss_since:None
  ~in_product_since:rel_miami
  ~params:[ Ref _pool_patch, "self", "The patch to apply"]  
  ()

let pool_patch =
  create_obj ~in_db:true 
    ~in_product_since:rel_miami 
    ~in_oss_since:None 
    ~internal_deprecated_since:None

    ~persist:PersistEverything 
    ~gen_constructor_destructor:false 
    ~gen_events:true

    ~name:_pool_patch 
    ~descr:"Pool-wide patches"
    ~doccomments:[]
    ~messages:[pool_patch_apply; pool_patch_pool_apply; pool_patch_precheck; pool_patch_clean; pool_patch_destroy]
    ~contents:
    [ uid       ~in_oss_since:None _pool_patch;
      namespace ~name:"name" ~contents:(names None StaticRO);
      field     ~in_product_since:rel_miami ~default_value:(Some (VString "")) ~in_oss_since:None ~qualifier:StaticRO ~ty:String "version" "Patch version number";
      field     ~in_product_since:rel_miami ~default_value:(Some (VString "")) ~in_oss_since:None ~internal_only:true ~qualifier:DynamicRO ~ty:String "filename" "Filename of the patch";
      field     ~in_product_since:rel_miami ~default_value:(Some (VInt Int64.zero)) ~in_oss_since:None ~qualifier:DynamicRO ~ty:Int "size" "Size of the patch";
      field     ~in_product_since:rel_miami ~default_value:(Some (VBool false)) ~in_oss_since:None ~qualifier:DynamicRO ~ty:Bool "pool_applied" "This patch should be applied across the entire pool";
      field     ~in_product_since:rel_miami ~in_oss_since:None ~qualifier:DynamicRO ~ty:(Set (Ref _host_patch)) "host_patches" "This hosts this patch is applied to.";
      field     ~in_product_since:rel_miami ~default_value:(Some (VSet [])) ~in_oss_since:None ~qualifier:DynamicRO ~ty:(Set pool_patch_after_apply_guidance) "after_apply_guidance" "What the client should do after this patch has been applied.";
      field     ~in_product_since:rel_miami ~default_value:(Some (VMap [])) ~in_oss_since:None  ~ty:(Map(String, String)) "other_config" "additional configuration";
    ] 
	()

(* Management of host patches. Just like the crash dumps it would be marginally neater if
   the patches were stored as VDIs. *)

let host_patch_destroy = call
  ~name:"destroy"
  ~doc:"Destroy the specified host patch, removing it from the disk. This does NOT reverse the patch"
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~params:[ Ref _host_patch, "self", "The patch to destroy" ]
  ~internal_deprecated_since: rel_miami
  ()

let host_patch_apply = call
  ~name:"apply"
  ~doc:"Apply the selected patch and return its output"
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~params:[ Ref _host_patch, "self", "The patch to apply" ]  
  ~result:(String, "the output of the patch application process")
  ~internal_deprecated_since: rel_miami
  ()

let host_patch = 
  create_obj ~in_db:true ~in_product_since:rel_rio ~in_oss_since:None ~internal_deprecated_since:None ~persist:PersistEverything ~gen_constructor_destructor:false ~name:_host_patch ~gen_events:true 
    ~descr:"Represents a patch stored on a server"
    ~doccomments:[]
    ~messages: [host_patch_destroy; host_patch_apply]
    ~contents:
    [ uid ~in_oss_since:None _host_patch;
      namespace ~name:"name" ~contents:(names None StaticRO);
      field ~in_oss_since:None ~qualifier:StaticRO ~ty:String "version" "Patch version number";
      field ~in_oss_since:None ~qualifier:StaticRO ~ty:(Ref _host) "host" "Host the patch relates to";
      field ~in_oss_since:None ~internal_only:true ~qualifier:DynamicRO ~ty:String "filename" "Filename of the patch";
      field ~in_oss_since:None ~qualifier:DynamicRO ~ty:Bool "applied" "True if the patch has been applied";
      field ~in_oss_since:None ~qualifier:DynamicRO ~ty:DateTime "timestamp_applied" "Time the patch was applied";
      field ~in_oss_since:None ~qualifier:DynamicRO ~ty:Int "size" "Size of the patch";
      field ~in_product_since:rel_miami ~in_oss_since:None ~qualifier:StaticRO ~ty:(Ref _pool_patch) ~default_value:(Some (VRef "")) "pool_patch" "The patch applied";
      field ~in_product_since:rel_miami ~default_value:(Some (VMap [])) ~in_oss_since:None  ~ty:(Map(String, String)) "other_config" "additional configuration";
    ]
    ()

let host_bugreport_upload = call
  ~name:"bugreport_upload"
  ~doc:"Run xen-bugtool --yestoall and upload the output to Citrix support"
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~params:[ Ref _host, "host", "The host on which to run xen-bugtool";
	    String, "url", "The URL to upload to";
	    Map(String, String), "options", "Extra configuration operations" ]
  ()

let host_list_methods = call
  ~name:"list_methods"
  ~in_product_since:rel_rio
  ~flags: [`Session]
  ~doc:"List all supported methods"
  ~params:[]
  ~result:(Set(String), "The name of every supported method.")
  ()

let host_license_apply = call
  ~name:"license_apply"
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~params:[Ref _host, "host", "The host to upload the license to";
	   String, "contents", "The contents of the license file, base64 encoded"]
  ~doc:"Apply a new license to a host"
  ~errs: [Api_errors.license_processing_error]
  ()

let host_create_params =
  [
    {param_type=String; param_name="uuid"; param_doc="unique identifier/object reference"; param_release=rio_release; param_default=None};
    {param_type=String; param_name="name_label"; param_doc="The name of the new storage repository"; param_release=rio_release; param_default=None};
    {param_type=String; param_name="name_description"; param_doc="The description of the new storage repository"; param_release=rio_release; param_default=None};
    {param_type=String; param_name="hostname"; param_doc="Hostname"; param_release=rio_release; param_default=None};
    {param_type=String; param_name="address"; param_doc="An address by which this host can be contacted by other members in its pool"; param_release=rio_release; param_default=None};
    {param_type=String; param_name="external_auth_type"; param_doc="type of external authentication service configured; empty if none configured"; param_release=george_release; param_default=Some(VString "")};
    {param_type=String; param_name="external_auth_service_name"; param_doc="name of external authentication service configured; empty if none configured"; param_release=george_release; param_default=Some(VString "")};
    {param_type=Map(String,String); param_name="external_auth_configuration"; param_doc="configuration specific to external authentication service"; param_release=george_release; param_default=Some(VMap [])};
  ]

let host_create = call
  ~name:"create"
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~versioned_params:host_create_params
  ~doc:"Create a new host record"
  ~result:(Ref _host, "Reference to the newly created host object.")
  ~hide_from_docs:true
    ()

let host_destroy = call
  ~name:"destroy"
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~doc:"Destroy specified host record in database"
  ~params:[(Ref _host, "self", "The host record to remove")]
  ()

let host_get_system_status_capabilities = call ~flags:[`Session]
  ~name:"get_system_status_capabilities"
  ~in_oss_since:None
  ~in_product_since:rel_miami
  ~params:[Ref _host, "host", "The host to interrogate"]
  ~doc:""
  ~result:(String, "An XML fragment containing the system status capabilities.")
    ()

let host_set_hostname_live = call ~flags:[`Session]
  ~name:"set_hostname_live"
  ~in_oss_since:None
  ~in_product_since:rel_miami
  ~params:[Ref _host, "host", "The host whose host name to set";
           String, "hostname", "The new host name"]
  ~errs:[Api_errors.host_name_invalid]
  ~doc:"Sets the host name to the specified string.  Both the API and lower-level system hostname are changed immediately."
    ()

let host_tickle_heartbeat = call ~flags:[`Session]
  ~name:"tickle_heartbeat"
  ~in_oss_since:None
  ~in_product_since:rel_orlando
  ~params:[Ref _host, "host", "The host calling the function, and whose heartbeat to tickle";
	   Map(String, String), "stuff", "Anything else we want to let the master know";
	  ]
  ~result:(Map(String, String), "Anything the master wants to tell the slave")
  ~doc:"Needs to be called every 30 seconds for the master to believe the host is alive"
  ~pool_internal:true
  ~hide_from_docs:true
  ()

let host_sync_data = call ~flags:[`Session]
  ~name:"sync_data"
  ~in_oss_since:None
  ~in_product_since:rel_orlando
  ~params:[Ref _host, "host", "The host to whom the data should be sent"]
  ~doc:"This causes the synchronisation of the non-database data (messages, RRDs and so on) stored on the master to be synchronised with the host"
  ()

let host_backup_rrds = call ~flags:[`Session]
  ~name:"backup_rrds"
  ~in_oss_since:None
  ~in_product_since:rel_orlando
  ~params:[Ref _host, "host", "Schedule a backup of the RRDs of this host";
	   Float, "delay", "Delay in seconds from when the call is received to perform the backup"]
  ~doc:"This causes the RRDs to be backed up to the master"
  ()

let host_get_servertime = call ~flags:[`Session]
  ~name:"get_servertime"
  ~in_oss_since:None
  ~in_product_since:rel_orlando
  ~params:[Ref _host, "host", "The host whose clock should be queried"]
  ~doc:"This call queries the host's clock for the current time"
  ~result:(DateTime, "The current time")
  ()

let host_emergency_ha_disable = call ~flags:[`Session]
  ~name:"emergency_ha_disable"
  ~in_oss_since:None
  ~in_product_since:rel_orlando
  ~params:[]
  ~doc:"This call disables HA on the local host. This should only be used with extreme care."
  ()

let host_certificate_install = call
  ~in_oss_since:None
  ~in_product_since:rel_george
  ~pool_internal:true
  ~hide_from_docs:true
  ~name:"certificate_install"
  ~doc:"Install an SSL certificate to this host."
  ~params:[Ref _host, "host", "The host";
           String, "name", "A name to give the certificate";
           String, "cert", "The certificate"]
  ()

let host_certificate_uninstall = call
  ~in_oss_since:None
  ~in_product_since:rel_george
  ~pool_internal:true
  ~hide_from_docs:true
  ~name:"certificate_uninstall"
  ~doc:"Remove an SSL certificate from this host."
  ~params:[Ref _host, "host", "The host";
           String, "name", "The certificate name"]
  ()

let host_certificate_list = call
  ~in_oss_since:None
  ~in_product_since:rel_george
  ~pool_internal:true
  ~hide_from_docs:true
  ~name:"certificate_list"
  ~doc:"List all installed SSL certificates."
  ~params:[Ref _host, "host", "The host"]
  ~result:(Set(String),"All installed certificates")
  ()

let host_crl_install = call
  ~in_oss_since:None
  ~in_product_since:rel_george
  ~pool_internal:true
  ~hide_from_docs:true
  ~name:"crl_install"
  ~doc:"Install an SSL certificate revocation list to this host."
  ~params:[Ref _host, "host", "The host";
           String, "name", "A name to give the CRL";
           String, "crl", "The CRL"]
  ()

let host_crl_uninstall = call
  ~in_oss_since:None
  ~in_product_since:rel_george
  ~pool_internal:true
  ~hide_from_docs:true
  ~name:"crl_uninstall"
  ~doc:"Remove an SSL certificate revocation list from this host."
  ~params:[Ref _host, "host", "The host";
           String, "name", "The CRL name"]
  ()

let host_crl_list = call
  ~in_oss_since:None
  ~in_product_since:rel_george
  ~pool_internal:true
  ~hide_from_docs:true
  ~name:"crl_list"
  ~doc:"List all installed SSL certificate revocation lists."
  ~params:[Ref _host, "host", "The host"]
  ~result:(Set(String),"All installed CRLs")
  ()

let host_certificate_sync = call
  ~in_oss_since:None
  ~in_product_since:rel_george
  ~pool_internal:true
  ~hide_from_docs:true
  ~name:"certificate_sync"
  ~doc:"Resync installed SSL certificates and CRLs."
  ~params:[Ref _host, "host", "The host"]
  ()

let host_get_server_certificate = call
  ~in_oss_since:None
  ~in_product_since:rel_george
  ~name:"get_server_certificate"
  ~doc:"Get the installed server SSL certificate."
  ~params:[Ref _host, "host", "The host"]
  ~result:(String,"The installed server SSL certificate, in PEM form.")
  ()

let host_operations =
  Enum ("host_allowed_operations", 
	[ "provision", "Indicates this host is able to provision another VM"; 
	  "evacuate", "Indicates this host is evacuating";
	  "shutdown", "Indicates this host is in the process of shutting itself down";
	  "reboot", "Indicates this host is in the process of rebooting";
	  "power_on", "Indicates this host is in the process of being powered on";
	  "vm_start", "This host is starting a VM";
	  "vm_resume", "This host is resuming a VM";
	  "vm_migrate", "This host is the migration target of a VM";
	])

let host_enable_external_auth = call ~flags:[`Session]
  ~name:"enable_external_auth"
  ~in_oss_since:None
  ~in_product_since:rel_george
  ~params:[
    Ref _host, "host", "The host whose external authentication should be enabled"; 
    Map (String,String), "config", "A list of key-values containing the configuration data" ; 
    String, "service_name", "The name of the service" ; 
    String, "auth_type", "The type of authentication (e.g. AD for Active Directory)" 
    ]
  ~doc:"This call enables external authentication on a host"
  ()

let host_disable_external_auth = call ~flags:[`Session]
  ~name:"disable_external_auth"
  ~in_oss_since:None
  ~in_product_since:rel_george
  ~versioned_params:[
    {param_type=Ref _host; param_name="host"; param_doc="The host whose external authentication should be disabled"; param_release=george_release; param_default=None};
    {param_type=Map (String, String); param_name="config"; param_doc="Optional parameters as a list of key-values containing the configuration data"; param_release=george_release; param_default=Some (VMap [])}
    ]
  ~doc:"This call disables external authentication on the local host"
  ()

let host_set_license_params = call
  ~name:"set_license_params"
  ~in_product_since:rel_orlando (* actually update 3 aka floodgate *)
  ~doc:"Set the new license details in the database, trigger a recomputation of the pool SKUU"
  ~params:[ 
    Ref _host, "self", "The host";
    Map(String, String), "value", "The license_params"
  ]
  ~hide_from_docs:true
  ~pool_internal:true
  ()

(** Hosts *)
let host =
    create_obj ~in_db:true ~in_product_since:rel_rio ~in_oss_since:oss_since_303 ~internal_deprecated_since:None ~persist:PersistEverything ~gen_constructor_destructor:false ~name:_host ~descr:"A physical host" ~gen_events:true
      ~doccomments:[]
      ~messages: [host_disable; host_enable; host_shutdown; host_reboot; host_dmesg; host_dmesg_clear; host_get_log; host_send_debug_keys; host_bugreport_upload; host_list_methods; host_license_apply; host_create; host_destroy; 
		  host_power_on;
		 host_set_license_params;
		 host_emergency_ha_disable;
		 host_ha_disarm_fencing; host_preconfigure_ha; host_ha_join_liveset; 
		 host_ha_disable_failover_decisions;
		 host_ha_wait_for_shutdown_via_statefile;
		 host_ha_stop_daemon;
		 host_ha_release_resources;
		 host_ha_xapi_healthcheck;
		 host_local_assert_healthy;
		 host_request_backup;
		 host_request_config_file_sync;
		 host_propose_new_master; host_commit_new_master; host_abort_new_master;
		 host_get_data_sources;
		 host_record_data_source;
		 host_query_data_source;
		 host_forget_data_source_archives;
		 host_assert_can_evacuate;
		 host_get_vms_which_prevent_evacuation;
		 host_get_uncooperative_resident_VMs;
		 host_get_uncooperative_domains;
		 host_evacuate;
		 host_signal_networking_change;
		 host_notify;
		 host_syslog_reconfigure;
		 host_management_reconfigure;
		 host_local_management_reconfigure;
		 host_management_disable;
		 host_get_system_status_capabilities;
		 host_get_diagnostic_timing_stats;
		 host_restart_agent;
		 host_shutdown_agent;
		 host_set_hostname_live;
		 host_is_in_emergency_mode;
		 host_compute_free_memory;
		 host_compute_memory_overhead;
		 host_tickle_heartbeat;
		 host_sync_data;
		 host_backup_rrds;
		 host_create_new_blob;
		 host_call_plugin;
		 host_get_servertime;
		 host_enable_binary_storage;
		 host_disable_binary_storage;
		 host_enable_external_auth;
		 host_disable_external_auth;
		 host_retrieve_wlb_evacuate_recommendations;
		 host_certificate_install;
		 host_certificate_uninstall;
		 host_certificate_list;
		 host_crl_install;
		 host_crl_uninstall;
		 host_crl_list;
		 host_certificate_sync;
		 host_get_server_certificate;
		 host_update_pool_secret;
		 host_update_master;
		 host_attach_static_vdis;
		 host_detach_static_vdis;
		 host_set_localdb_key;
		 ]
      ~contents:
        ([ uid _host;
	namespace ~name:"name" ~contents:(names None RW);
	namespace ~name:"memory" ~contents:host_memory;
	] @ (allowed_and_current_operations host_operations) @ [
	namespace ~name:"API_version" ~contents:api_version;
	field ~qualifier:DynamicRO ~ty:Bool "enabled" "True if the host is currently enabled";
	field ~qualifier:StaticRO ~ty:(Map(String, String)) "software_version" "version strings";
	field ~ty:(Map(String, String)) "other_config" "additional configuration";
	field ~qualifier:StaticRO ~ty:(Set(String)) "capabilities" "Xen capabilities";
	field ~qualifier:DynamicRO ~ty:(Map(String, String)) "cpu_configuration" "The CPU configuration on this host.  May contain keys such as \"nr_nodes\", \"sockets_per_node\", \"cores_per_socket\", or \"threads_per_core\"";
	field ~qualifier:DynamicRO ~ty:String "sched_policy" "Scheduler policy currently in force on this host";
	field ~qualifier:DynamicRO ~ty:(Set String) "supported_bootloaders" "a list of the bootloaders installed on the machine";
	field ~qualifier:DynamicRO ~ty:(Set (Ref _vm)) "resident_VMs" "list of VMs currently resident on host";
	field ~qualifier:RW ~ty:(Map(String, String)) "logging" "logging configuration";
	field ~qualifier:DynamicRO ~ty:(Set (Ref _pif)) "PIFs" "physical network interfaces";
	field ~qualifier:RW ~ty:(Ref _sr) "suspend_image_sr" "The SR in which VDIs for suspend images are created";
	field ~qualifier:RW ~ty:(Ref _sr) "crash_dump_sr" "The SR in which VDIs for crash dumps are created";
	field ~in_oss_since:None ~qualifier:DynamicRO ~ty:(Set (Ref _host_crashdump)) "crashdumps" "Set of host crash dumps";
	field ~in_oss_since:None ~qualifier:DynamicRO ~ty:(Set (Ref _host_patch)) "patches" "Set of host patches";
	field ~qualifier:DynamicRO ~ty:(Set (Ref _pbd)) "PBDs" "physical blockdevices";
	field ~qualifier:DynamicRO ~ty:(Set (Ref _hostcpu)) "host_CPUs" "The physical CPUs on this host";
	field ~in_oss_since:None ~qualifier:RW ~ty:String "hostname" "The hostname of this host";
	field ~in_oss_since:None ~qualifier:RW ~ty:String "address" "The address by which this host can be contacted from any other host in the pool";
	field ~qualifier:DynamicRO ~ty:(Ref _host_metrics) "metrics" "metrics associated with this host";
	field ~in_oss_since:None ~qualifier:DynamicRO ~ty:(Map (String,String)) "license_params" "The key/value pairs read from the license file";
	field ~in_oss_since:None ~internal_only:true ~qualifier:DynamicRO ~ty:Int "boot_free_mem" "Free memory on host at boot time";
	field ~in_oss_since:None ~qualifier:DynamicRO ~in_product_since:rel_orlando ~ty:(Set String) ~default_value:(Some (VSet [])) "ha_statefiles" "The set of statefiles accessible from this host";
	field ~in_oss_since:None ~qualifier:DynamicRO ~in_product_since:rel_orlando ~ty:(Set String) ~default_value:(Some (VSet [])) "ha_network_peers" "The set of hosts visible via the network from this host";
	field ~qualifier:DynamicRO ~in_product_since:rel_orlando ~ty:(Map(String,Ref _blob)) ~default_value:(Some (VMap [])) "blobs" "Binary blobs associated with this host";
	field ~qualifier:RW ~in_product_since:rel_orlando ~default_value:(Some (VSet [])) ~ty:(Set String) "tags" "user-specified tags for categorization purposes";

	field ~qualifier:DynamicRO ~in_product_since:rel_george ~default_value:(Some (VString "")) ~ty:String "external_auth_type" "type of external authentication service configured; empty if none configured.";
	field ~qualifier:DynamicRO ~in_product_since:rel_george ~default_value:(Some (VString "")) ~ty:String "external_auth_service_name" "name of external authentication service configured; empty if none configured.";
	field ~qualifier:DynamicRO ~in_product_since:rel_george ~default_value:(Some (VMap [])) ~ty:(Map (String,String)) "external_auth_configuration" "configuration specific to external authentication service";


 ])
	()

let host_metrics = 
    create_obj ~in_db:true ~in_product_since:rel_rio ~in_oss_since:oss_since_303 ~internal_deprecated_since:None ~persist:PersistEverything ~gen_constructor_destructor:false ~name:_host_metrics ~descr:"The metrics associated with a host" ~gen_events:true
      ~doccomments:[]
      ~messages:[] ~contents:
      [ uid _host_metrics;
	namespace ~name:"memory" ~contents:host_metrics_memory;
	field ~qualifier:DynamicRO ~ty:Bool ~in_oss_since:None "live" "Pool master thinks this host is live";
	field ~qualifier:DynamicRO ~ty:DateTime "last_updated" "Time at which this information was last updated";
	field ~in_product_since:rel_orlando ~default_value:(Some (VMap [])) ~ty:(Map(String, String)) "other_config" "additional configuration";
      ]
	()

(** HostCPU *)

let hostcpu =
    create_obj ~in_db:true ~in_product_since:rel_rio ~in_oss_since:oss_since_303 ~internal_deprecated_since:None ~persist:PersistEverything ~gen_constructor_destructor:false ~name:_hostcpu ~descr:"A physical CPU" ~gen_events:true
      ~doccomments:[] 
      ~messages:[] ~contents:
      [ uid _hostcpu;
	field ~qualifier:DynamicRO ~ty:(Ref _host) "host" "the host the CPU is in";
	field ~qualifier:DynamicRO ~ty:Int "number" "the number of the physical CPU within the host";
	field ~qualifier:DynamicRO ~ty:String "vendor" "the vendor of the physical CPU";
	field ~qualifier:DynamicRO ~ty:Int "speed" "the speed of the physical CPU";
	field ~qualifier:DynamicRO ~ty:String "modelname" "the model name of the physical CPU";
	field ~qualifier:DynamicRO ~ty:Int "family" "the family (number) of the physical CPU";
	field ~qualifier:DynamicRO ~ty:Int "model" "the model number of the physical CPU";
	field ~qualifier:DynamicRO ~ty:String "stepping" "the stepping of the physical CPU";
	field ~qualifier:DynamicRO ~ty:String "flags" "the flags of the physical CPU (a decoded version of the features field)";
	field ~qualifier:DynamicRO ~ty:String "features" "the physical CPU feature bitmap";
	field ~qualifier:DynamicRO ~persist:false ~ty:Float "utilisation" "the current CPU utilisation";
	field ~in_product_since:rel_orlando ~default_value:(Some (VMap [])) ~ty:(Map(String, String)) "other_config" "additional configuration";
]
	()

(** Disk and network interfaces are associated with QoS parameters: *)
let qos devtype =
  [ field  "algorithm_type" "QoS algorithm to use";
    field  ~ty:(Map(String,String)) "algorithm_params" 
      "parameters for chosen QoS algorithm";
    field ~qualifier:DynamicRO  ~ty:(Set String) "supported_algorithms"
      ("supported QoS algorithms for this " ^ devtype);
  ]

let network_operations =
  Enum ("network_operations", 
	[ "attaching", "Indicates this network is attaching to a VIF or PIF" ])

let network_attach = call
  ~name:"attach"
  ~doc:"Makes the network immediately available on a particular host"
  ~params:[Ref _network, "network", "network to which this interface should be connected";
	   Ref _host, "host", "physical machine to which this PIF is connected"]
  ~in_product_since:rel_miami  
  ~hide_from_docs:true
  ()

let network_introduce_params first_rel =
  [
    {param_type=String; param_name="name_label"; param_doc=""; param_release=first_rel; param_default=None};
    {param_type=String; param_name="name_description"; param_doc=""; param_release=first_rel; param_default=None};
    {param_type=Map(String,String); param_name="other_config"; param_doc=""; param_release=first_rel; param_default=None};
    {param_type=String; param_name="bridge"; param_doc=""; param_release=first_rel; param_default=None};
  ]

(* network pool introduce is used to copy network records on pool join -- it's the network analogue of VDI/PIF.pool_introduce *)
let network_pool_introduce = call
  ~name:"pool_introduce"
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~versioned_params:(network_introduce_params miami_release)
  ~doc:"Create a new network record in the database only"
  ~result:(Ref _network, "The ref of the newly created network record.")
  ~hide_from_docs:true
    ()

let network_create_new_blob = call
  ~name: "create_new_blob"
  ~in_product_since:rel_orlando
  ~doc:"Create a placeholder for a named binary blob of data that is associated with this pool"
  ~params:[Ref _network, "network", "The network";
	   String, "name", "The name associated with the blob";
	   String, "mime_type", "The mime type for the data. Empty string translates to application/octet-stream";]
  ~result:(Ref _blob, "The reference of the blob, needed for populating its data")
  ()

(** A virtual network *)
let network =
    create_obj ~in_db:true ~in_product_since:rel_rio ~in_oss_since:oss_since_303 ~internal_deprecated_since:None ~persist:PersistEverything ~gen_constructor_destructor:true ~name:_network ~descr:"A virtual network" ~gen_events:true
      ~doccomments:[] 
      ~messages:[ network_attach; network_pool_introduce; network_create_new_blob ] ~contents: 
      ([
      uid _network;
      namespace ~name:"name" ~contents:(names oss_since_303 RW);
    ] @ (allowed_and_current_operations network_operations) @ [
      field ~qualifier:DynamicRO ~ty:(Set (Ref _vif)) "VIFs" "list of connected vifs";
      field ~qualifier:DynamicRO ~ty:(Set (Ref _pif)) "PIFs" "list of connected pifs";
      field ~ty:(Map(String, String)) "other_config" "additional configuration" ;
      field ~in_oss_since:None ~qualifier:DynamicRO "bridge" "name of the bridge corresponding to this network on the local host";
      field ~qualifier:DynamicRO ~in_product_since:rel_orlando ~ty:(Map(String, Ref _blob)) ~default_value:(Some (VMap [])) "blobs" "Binary blobs associated with this network";
      field  ~in_product_since:rel_orlando ~default_value:(Some (VSet [])) ~ty:(Set String) "tags" "user-specified tags for categorization purposes"
       ])
     ()

let pif_create_VLAN = call
  
  ~name:"create_VLAN"
  ~in_product_since:rel_rio
  ~doc:"Create a VLAN interface from an existing physical interface. This call is deprecated: use VLAN.create instead"
  ~params:[String, "device", "physical interface on which to create the VLAN interface";
	   Ref _network, "network", "network to which this interface should be connected";
	   Ref _host, "host", "physical machine to which this PIF is connected";
	   Int, "VLAN", "VLAN tag for the new interface"]
  ~result:(Ref _pif, "The reference of the created PIF object")
  ~errs:[Api_errors.vlan_tag_invalid]
  ~internal_deprecated_since:rel_miami
  ()

let pif_destroy = call
  ~name:"destroy"
  ~in_product_since:rel_rio
  ~doc:"Destroy the PIF object (provided it is a VLAN interface). This call is deprecated: use VLAN.destroy or Bond.destroy instead"
  ~params:[Ref _pif, "self", "the PIF object to destroy"]
  ~errs:[Api_errors.pif_is_physical]
  ~internal_deprecated_since:rel_miami
  ()

let pif_plug = call
  ~name:"plug"
  ~doc:"Attempt to bring up a physical interface"
  ~params:[Ref _pif, "self", "the PIF object to plug"]
  ~in_product_since:rel_miami
  ()

let pif_unplug = call
  ~name:"unplug"
  ~doc:"Attempt to bring down a physical interface"
  ~params:[Ref _pif, "self", "the PIF object to unplug"]
  ~in_product_since:rel_miami
  ()

let pif_ip_configuration_mode = Enum ("ip_configuration_mode",
				      [ "None", "Do not acquire an IP address";
					"DHCP", "Acquire an IP address by DHCP";
					"Static", "Static IP address configuration" ])

let pif_reconfigure_ip = call
  ~name:"reconfigure_ip"
  ~doc:"Reconfigure the IP address settings for this interface"
  ~params:[Ref _pif, "self", "the PIF object to reconfigure";
	   pif_ip_configuration_mode, "mode", "whether to use dynamic/static/no-assignment";
	   String, "IP", "the new IP address";
	   String, "netmask", "the new netmask";
	   String, "gateway", "the new gateway";
	   String, "DNS", "the new DNS settings";
	  ]
  ~in_product_since:rel_miami
  ()

let pif_scan = call
  ~name:"scan"
  ~doc:"Scan for physical interfaces on a host and create PIF objects to represent them"
  ~params:[Ref _host, "host", "The host on which to scan"]
  ~in_product_since:rel_miami
  ()

let pif_introduce = call
  ~name:"introduce"
  ~doc:"Create a PIF object matching a particular network interface"
  ~params:[Ref _host, "host", "The host on which the interface exists";
	   String, "MAC", "The MAC address of the interface";
	   String, "device", "The device name to use for the interface";
	  ]
  ~in_product_since:rel_miami
  ~result:(Ref _pif, "The reference of the created PIF object")
  ()

let pif_forget = call
  ~name:"forget"
  ~doc:"Destroy the PIF object matching a particular network interface"
  ~params:[Ref _pif, "self", "The PIF object to destroy"]
  ~in_product_since:rel_miami
  ()

let pif_introduce_params first_rel =
  [
    {param_type=String; param_name="device"; param_doc=""; param_release=first_rel; param_default=None};
    {param_type=Ref _network; param_name="network"; param_doc=""; param_release=first_rel; param_default=None};
    {param_type=Ref _host; param_name="host"; param_doc=""; param_release=first_rel; param_default=None};
    {param_type=String; param_name="MAC"; param_doc=""; param_release=first_rel; param_default=None};
    {param_type=Int; param_name="MTU"; param_doc=""; param_release=first_rel; param_default=None};
    {param_type=Int; param_name="VLAN"; param_doc=""; param_release=first_rel; param_default=None};
    {param_type=Bool; param_name="physical"; param_doc=""; param_release=first_rel; param_default=None};
    {param_type=pif_ip_configuration_mode; param_name="ip_configuration_mode"; param_doc=""; param_release=first_rel; param_default=None};
    {param_type=String; param_name="IP"; param_doc=""; param_release=first_rel; param_default=None};
    {param_type=String; param_name="netmask"; param_doc=""; param_release=first_rel; param_default=None};
    {param_type=String; param_name="gateway"; param_doc=""; param_release=first_rel; param_default=None};
    {param_type=String; param_name="DNS"; param_doc=""; param_release=first_rel; param_default=None};
    {param_type=Ref _bond; param_name="bond_slave_of"; param_doc=""; param_release=first_rel; param_default=None};
    {param_type=Ref _vlan; param_name="VLAN_master_of"; param_doc=""; param_release=first_rel; param_default=None};
    {param_type=Bool; param_name="management"; param_doc=""; param_release=first_rel; param_default=None};
    {param_type=Map(String, String); param_name="other_config"; param_doc=""; param_release=first_rel; param_default=None};
    {param_type=Bool; param_name="disallow_unplug"; param_doc=""; param_release=orlando_release; param_default=Some (VBool false)}
  ]

(* PIF pool introduce is used to copy PIF records on pool join -- it's the PIF analogue of VDI.pool_introduce *)
let pif_pool_introduce = call
  ~name:"pool_introduce"
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~versioned_params:(pif_introduce_params miami_release)
  ~doc:"Create a new PIF record in the database only"
  ~result:(Ref _pif, "The ref of the newly created PIF record.")
  ~hide_from_docs:true
    ()

let pif_db_introduce = call
  ~name:"db_introduce"
  ~in_oss_since:None
  ~in_product_since:rel_orlando
  ~versioned_params:(pif_introduce_params orlando_release)
  ~doc:"Create a new PIF record in the database only"
  ~result:(Ref _pif, "The ref of the newly created PIF record.")
  ~hide_from_docs:false
  ()


let pif_db_forget = call
  ~name:"db_forget"
  ~in_oss_since:None
  ~in_product_since:rel_orlando
  ~params:[ Ref _pif, "self", "The ref of the PIF whose database record should be destroyed" ]
  ~doc:"Destroy a PIF database record."
  ~hide_from_docs:false
  ()

let pif = 
    create_obj ~in_db:true ~in_product_since:rel_rio ~in_oss_since:oss_since_303 ~internal_deprecated_since:None ~persist:PersistEverything ~gen_constructor_destructor:false ~name:_pif ~descr:"A physical network interface (note separate VLANs are represented as several PIFs)"
      ~gen_events:true
      ~doccomments:[] 
      ~messages:[pif_create_VLAN; pif_destroy; pif_reconfigure_ip; pif_scan; pif_introduce; pif_forget;
		pif_unplug; pif_plug; pif_pool_introduce;
		pif_db_introduce; pif_db_forget
		] ~contents:
      [ uid _pif;
	(* qualifier changed RW -> StaticRO in Miami *)
	field ~qualifier:StaticRO "device" "machine-readable name of the interface (e.g. eth0)";
	field ~qualifier:StaticRO ~ty:(Ref _network) "network" "virtual network to which this pif is connected";
	field ~qualifier:StaticRO ~ty:(Ref _host) "host" "physical machine to which this pif is connected";
	(* qualifier changed RW -> StaticRO in Miami *)
	field ~qualifier:StaticRO "MAC" "ethernet MAC address of physical interface";
	(* qualifier changed RW -> StaticRO in Miami *)
	field ~qualifier:StaticRO ~ty:Int "MTU" "MTU in octets";
	(* qualifier changed RW -> StaticRO in Miami *)
	field ~qualifier:StaticRO ~ty:Int "VLAN" "VLAN tag for all traffic passing through this interface";
	field ~in_oss_since:None ~internal_only:true "device_name" "actual dom0 device name";
	field ~qualifier:DynamicRO ~ty:(Ref _pif_metrics) "metrics" "metrics associated with this PIF";
	field ~in_oss_since:None ~ty:Bool ~in_product_since:rel_miami ~qualifier:DynamicRO "physical" "true if this represents a physical network interface" ~default_value:(Some (VBool false));
	field ~in_oss_since:None ~ty:Bool ~in_product_since:rel_miami ~qualifier:DynamicRO "currently_attached" "true if this interface is online" ~default_value:(Some (VBool true));
	field ~in_oss_since:None ~ty:pif_ip_configuration_mode ~in_product_since:rel_miami ~qualifier:DynamicRO "ip_configuration_mode" "Sets if and how this interface gets an IP address" ~default_value:(Some (VEnum "None"));
	field ~in_oss_since:None ~ty:String ~in_product_since:rel_miami ~qualifier:DynamicRO "IP" "IP address" ~default_value:(Some (VString ""));
	field ~in_oss_since:None ~ty:String ~in_product_since:rel_miami ~qualifier:DynamicRO "netmask" "IP netmask" ~default_value:(Some (VString ""));
	field ~in_oss_since:None ~ty:String ~in_product_since:rel_miami ~qualifier:DynamicRO "gateway" "IP gateway" ~default_value:(Some (VString ""));
	field ~in_oss_since:None ~ty:String ~in_product_since:rel_miami ~qualifier:DynamicRO "DNS" "IP address of DNS servers to use" ~default_value:(Some (VString ""));
	field ~in_oss_since:None ~ty:(Ref _bond) ~in_product_since:rel_miami ~qualifier:DynamicRO "bond_slave_of" "indicates which bond this interface is part of" ~default_value:(Some (VRef ""));
	field ~in_oss_since:None ~ty:(Set(Ref _bond)) ~in_product_since:rel_miami ~qualifier:DynamicRO "bond_master_of" "indicates this PIF represents the results of a bond";	
	field ~in_oss_since:None ~ty:(Ref _vlan) ~in_product_since:rel_miami ~qualifier:DynamicRO "VLAN_master_of" "indicates wich VLAN this interface receives untagged traffic from" ~default_value:(Some (VRef ""));
	field ~in_oss_since:None ~ty:(Set(Ref _vlan)) ~in_product_since:rel_miami ~qualifier:DynamicRO "VLAN_slave_of" "indicates which VLANs this interface transmits tagged traffic to";
	field ~in_oss_since:None ~ty:Bool ~in_product_since:rel_miami ~qualifier:DynamicRO "management" "indicates whether the control software is listening for connections on this interface" ~default_value:(Some (VBool false));
	field ~in_product_since:rel_miami ~default_value:(Some (VMap [])) ~ty:(Map(String, String)) "other_config" "additional configuration";
	field ~in_product_since:rel_orlando ~default_value:(Some (VBool false)) ~ty:Bool "disallow_unplug" "prevent this PIF from being unplugged; set this to notify the management tool-stack that the PIF has a special use and should not be unplugged under any circumstances (e.g. because you're running storage traffic over it)";
      ]
	()

let pif_metrics = 
    create_obj ~in_db:true ~in_product_since:rel_rio ~in_oss_since:oss_since_303 ~internal_deprecated_since:None ~persist:PersistNothing ~gen_constructor_destructor:false ~name:_pif_metrics ~descr:"The metrics associated with a physical network interface"
      ~gen_events:true
      ~doccomments:[]
      ~messages:[] ~contents:
      [ uid _pif_metrics;
	namespace ~name:"io" ~contents:iobandwidth;
	field ~qualifier:DynamicRO ~ty:Bool "carrier" "Report if the PIF got a carrier or not";
	field ~qualifier:DynamicRO ~ty:String "vendor_id" "Report vendor ID";
	field ~qualifier:DynamicRO ~ty:String "vendor_name" "Report vendor name";
	field ~qualifier:DynamicRO ~ty:String "device_id" "Report device ID";
	field ~qualifier:DynamicRO ~ty:String "device_name" "Report device name";
	field ~qualifier:DynamicRO ~ty:Int "speed" "Speed of the link (if available)";
	field ~qualifier:DynamicRO ~ty:Bool "duplex" "Full duplex capability of the link (if available)";
	field ~qualifier:DynamicRO ~ty:String "pci_bus_path" "PCI bus path of the pif (if available)";
	field ~qualifier:DynamicRO ~ty:DateTime "last_updated" "Time at which this information was last updated";
	field ~in_product_since:rel_orlando ~default_value:(Some (VMap [])) ~ty:(Map(String, String)) "other_config" "additional configuration";
      ]
	()

let bond_create = call
  ~name:"create"
  ~doc:"Create an interface bond"
  ~params:[ Ref _network, "network", "Network to add the bonded PIF to";
	    Set (Ref _pif), "members", "PIFs to add to this bond";
	    String, "MAC", "The MAC address to use on the bond itself. If this parameter is the empty string then the bond will inherit its MAC address from the first of the specified 'members'"
	  ]
  ~result:(Ref _bond, "The reference of the created Bond object")
  ~in_product_since:rel_miami
  ()

let bond_destroy = call
  ~name:"destroy"
  ~doc:"Destroy an interface bond"
  ~params:[Ref _bond, "self", "Bond to destroy"]
  ~in_product_since:rel_miami
  ()

let bond = 
  create_obj ~in_db:true ~in_product_since:rel_miami ~in_oss_since:None ~internal_deprecated_since:None ~persist:PersistEverything ~gen_constructor_destructor:false ~name:_bond ~descr:"" ~gen_events:true ~doccomments:[]
    ~messages:[ bond_create; bond_destroy ] 
    ~contents:
    [ uid _bond;
      field ~in_oss_since:None ~in_product_since:rel_miami ~qualifier:StaticRO ~ty:(Ref _pif) "master" "The bonded interface" ~default_value:(Some (VRef ""));
      field ~in_oss_since:None ~in_product_since:rel_miami ~qualifier:DynamicRO ~ty:(Set(Ref _pif)) "slaves" "The interfaces which are part of this bond";
      field ~in_product_since:rel_miami ~default_value:(Some (VMap [])) ~ty:(Map(String, String)) "other_config" "additional configuration";
    ]
    ()

let vlan_create = call
  ~name:"create"
  ~doc:"Create a VLAN mux/demuxer"
  ~params:[ Ref _pif, "tagged_PIF", "PIF which receives the tagged traffic";
	    Int, "tag", "VLAN tag to use";
	    Ref _network, "network", "Network to receive the untagged traffic" ]
  ~result:(Ref _vlan, "The reference of the created VLAN object")
  ~in_product_since:rel_miami
  ()

let vlan_destroy = call
  ~name:"destroy"
  ~doc:"Destroy a VLAN mux/demuxer"
  ~params:[Ref _vlan, "self", "VLAN mux/demuxer to destroy"]
  ~in_product_since:rel_miami
  ()

let vlan = 
  create_obj ~in_db:true ~in_product_since:rel_miami ~in_oss_since:None ~internal_deprecated_since:None ~persist:PersistEverything ~gen_constructor_destructor:false ~name:_vlan ~descr:"A VLAN mux/demux" ~gen_events:true
    ~doccomments:[]
    ~messages:[ vlan_create; vlan_destroy ] ~contents:
    ([
       uid _vlan;
       field ~qualifier:StaticRO ~ty:(Ref _pif) ~in_product_since:rel_miami "tagged_PIF" "interface on which traffic is tagged" ~default_value:(Some (VRef ""));
       field ~qualifier:DynamicRO ~ty:(Ref _pif) ~in_product_since:rel_miami "untagged_PIF" "interface on which traffic is untagged" ~default_value:(Some (VRef ""));
       field ~qualifier:StaticRO ~ty:Int ~in_product_since:rel_miami "tag" "VLAN tag in use" ~default_value:(Some (VInt (-1L)));
       field ~in_product_since:rel_miami ~default_value:(Some (VMap [])) ~ty:(Map(String, String)) "other_config" "additional configuration";	  
     ])
    ()

 let pbd_set_device_config = call
   ~name:"set_device_config"
   ~in_oss_since:None
   ~in_product_since:rel_miami
   ~params:[Ref _pbd, "self", "The PBD to modify";
	    Map(String, String), "value", "The new value of the PBD's device_config"]
   ~doc:"Sets the PBD's device_config field"
   ()

let pbd =
  create_obj ~in_db:true ~in_product_since:rel_rio ~in_oss_since:oss_since_303 ~internal_deprecated_since:None ~persist:PersistEverything ~gen_constructor_destructor:true ~name:_pbd ~descr:"The physical block devices through which hosts access SRs"
    ~gen_events:true
    ~doccomments:[]
    ~messages:[ 
      pbd_plug; pbd_unplug;
      pbd_set_device_config
	      ] ~contents:
    [ uid _pbd;
      field ~qualifier:StaticRO ~ty:(Ref _host) "host" "physical machine on which the pbd is available";
      field ~qualifier:StaticRO ~ty:(Ref _sr) "SR" "the storage repository that the pbd realises";
      field ~ty:(Map(String, String)) ~qualifier:StaticRO "device_config" "a config string to string map that is provided to the host's SR-backend-driver";
      field ~ty:Bool ~qualifier:DynamicRO "currently_attached" "is the SR currently attached on this host?";
      field ~in_product_since:rel_miami ~default_value:(Some (VMap [])) ~ty:(Map(String, String)) "other_config" "additional configuration";
    ]
    ()

(* These are included in vbds and vifs -- abstracted here to keep both these uses consistent *)
let device_status_fields =
  [
    field ~ty:Bool ~qualifier:DynamicRO "currently_attached" "is the device currently attached (erased on reboot)";
    field ~ty:Int ~qualifier:DynamicRO "status_code" "error/success code associated with last attach-operation (erased on reboot)";
    field ~ty:String ~qualifier:DynamicRO "status_detail" "error/success information associated with last attach-operation status (erased on reboot)";
    field ~ty:(Map(String, String)) ~qualifier:DynamicRO "runtime_properties" "Device runtime properties"
  ]

(* VIF messages *)

let vif_plug = call
  ~name:"plug"
  ~in_product_since:rel_rio
  ~doc:"Hotplug the specified VIF, dynamically attaching it to the running VM"
  ~params:[Ref _vif, "self", "The VIF to hotplug"]
  ()

let vif_unplug = call
  ~name:"unplug"
  ~in_product_since:rel_rio
  ~doc:"Hot-unplug the specified VIF, dynamically unattaching it from the running VM"
  ~params:[Ref _vif, "self", "The VIF to hot-unplug"]
  ()

let vif_operations =
  Enum ("vif_operations", 
	[ "attach", "Attempting to attach this VIF to a VM";
	  "plug", "Attempting to hotplug this VIF";
	  "unplug", "Attempting to hot unplug this VIF"; ])

(** A virtual network interface *)
let vif =
    create_obj ~in_db:true ~in_product_since:rel_rio ~in_oss_since:oss_since_303 ~internal_deprecated_since:None ~persist:PersistEverything ~gen_constructor_destructor:true ~name:_vif ~descr:"A virtual network interface"
      ~gen_events:true
      ~doccomments:[] 
      ~messages:[vif_plug; vif_unplug] ~contents:
      ([ uid _vif;
       ] @ (allowed_and_current_operations vif_operations) @ [
	 field ~qualifier:StaticRO "device" "order in which VIF backends are created by xapi";
	 field ~qualifier:StaticRO ~ty:(Ref _network) "network" "virtual network to which this vif is connected";
	 field ~qualifier:StaticRO ~ty:(Ref _vm) "VM" "virtual machine to which this vif is connected";
	 field ~qualifier:StaticRO ~ty:String "MAC" "ethernet MAC address of virtual interface, as exposed to guest";
	 field ~qualifier:StaticRO ~ty:Int "MTU" "MTU in octets";
	 field ~in_oss_since:None ~internal_only:true ~qualifier:DynamicRO ~ty:Bool "reserved" "true if the VIF is reserved pending a reboot/migrate";
	 field ~ty:(Map(String, String)) "other_config" "additional configuration";
       ] @ device_status_fields @
	 [ namespace ~name:"qos" ~contents:(qos "VIF"); ] @
	 [ field ~qualifier:DynamicRO ~ty:(Ref _vif_metrics) "metrics" "metrics associated with this VIF";
	   field ~qualifier:DynamicRO ~in_product_since:rel_george ~default_value:(Some (VBool false)) ~ty:Bool "MAC_autogenerated" "true if the MAC was autogenerated; false indicates it was set manually"
	 ])
	()

let vif_metrics = 
    create_obj ~in_db:true ~in_product_since:rel_rio ~in_oss_since:oss_since_303 ~internal_deprecated_since:None ~persist:PersistNothing ~gen_constructor_destructor:false ~name:_vif_metrics ~descr:"The metrics associated with a virtual network device"
      ~gen_events:true
      ~doccomments:[]
      ~messages:[] ~contents:
      [ uid _vif_metrics;
	namespace ~name:"io" ~contents:iobandwidth;
	field ~qualifier:DynamicRO ~ty:DateTime "last_updated" "Time at which this information was last updated";
	field ~in_product_since:rel_orlando ~default_value:(Some (VMap [])) ~ty:(Map(String, String)) "other_config" "additional configuration";
      ]
	()

let data_source =
  create_obj ~in_db:false ~in_product_since:rel_orlando ~in_oss_since:None ~internal_deprecated_since:None ~persist:PersistNothing ~gen_constructor_destructor:false ~name:_data_source ~descr:"Data sources for logging in RRDs" 
    ~gen_events:false
    ~doccomments:[]
    ~messages:[] ~contents:
    [ namespace ~name:"name" ~contents:(names oss_since_303 DynamicRO);
      field ~qualifier:DynamicRO ~ty:Bool "enabled" "true if the data source is being logged";
      field ~qualifier:DynamicRO ~ty:Bool "standard" "true if the data source is enabled by default. Non-default data sources cannot be disabled";
      field ~qualifier:DynamicRO ~ty:String "units" "the units of the value";
      field ~qualifier:DynamicRO ~ty:Float "min" "the minimum value of the data source";
      field ~qualifier:DynamicRO ~ty:Float "max" "the maximum value of the data source";
      field ~qualifier:DynamicRO ~ty:Float "value" "current value of the data source" ]
      
    ()

let storage_operations =
  Enum ("storage_operations", 
	[ "scan", "Scanning backends for new or deleted VDIs";
	  "destroy", "Destroying the SR";
	  "forget", "Forgetting about SR";
	  "plug", "Plugging a PBD into this SR";
	  "unplug", "Unplugging a PBD from this SR";
	  "update", "Refresh the fields on the SR";
	  "vdi_create", "Creating a new VDI";
	  "vdi_introduce", "Introducing a new VDI";
	  "vdi_destroy", "Destroying a VDI";
	  "vdi_resize", "Resizing a VDI"; 
	  "vdi_clone", "Cloneing a VDI"; 
	  "vdi_snapshot", "Snapshotting a VDI" ])

 let sr_set_virtual_allocation = call
   ~name:"set_virtual_allocation"
   ~in_oss_since:None
   ~in_product_since:rel_miami
   ~params:[Ref _sr, "self", "The SR to modify";
 	   Int, "value", "The new value of the SR's virtual_allocation"]
   ~flags:[`Session]
   ~doc:"Sets the SR's virtual_allocation field"
   ()

 let sr_set_physical_size = call
   ~name:"set_physical_size"
   ~in_oss_since:None
   ~in_product_since:rel_miami
   ~params:[Ref _sr, "self", "The SR to modify";
 	   Int, "value", "The new value of the SR's physical_size"]
   ~flags:[`Session]
   ~doc:"Sets the SR's physical_size field"
   ()

 let sr_set_physical_utilisation = call
   ~name:"set_physical_utilisation"
   ~in_oss_since:None
   ~in_product_since:rel_miami
   ~flags:[`Session]
   ~params:[Ref _sr, "self", "The SR to modify";
 	   Int, "value", "The new value of the SR's physical utilisation"]
   ~doc:"Sets the SR's physical_utilisation field"
   ()

 let sr_update = call
   ~name:"update"
   ~in_oss_since:None
   ~in_product_since:rel_symc
   ~params:[Ref _sr, "sr", "The SR whose fields should be refreshed" ]
   ~doc:"Refresh the fields on the SR object"
   ()

 let sr_assert_can_host_ha_statefile = call
   ~name:"assert_can_host_ha_statefile"
   ~in_oss_since:None
   ~in_product_since:rel_orlando
   ~params:[Ref _sr, "sr", "The SR to query" ]
   ~doc:"Returns successfully if the given SR can host an HA statefile. Otherwise returns an error to explain why not"
   ()

 let sr_lvhd_stop_using_these_vdis_and_call_script = call
   ~name:"lvhd_stop_using_these_vdis_and_call_script"
   ~in_oss_since:None
   ~in_product_since:rel_george
   ~params:[Set(Ref _vdi), "vdis", "The VDIs to stop using";
	    String, "plugin", "Name of the plugin script to call";
	    String, "fn", "Name of the function within the script to call";
	    Map(String, String), "args", "Arguments to pass to the script"]
   ~result:(String, "output from the lvhd script hook")
   ~doc:"Pauses active VBDs associated with the given VDIs and prevents other VDIs becoming active; then calls a script and unwinds"
   ~hide_from_docs:true
   ()

(** A storage repository. Note we overide default create/destroy methods with our own here... *)
let storage_repository =
    create_obj ~in_db:true ~in_product_since:rel_rio ~in_oss_since:oss_since_303 ~internal_deprecated_since:None ~persist:PersistEverything ~gen_constructor_destructor:false ~name:_sr ~descr:"A storage repository"
      ~gen_events:true
      ~doccomments:[] 
      ~messages:[ sr_create; sr_introduce; sr_make; sr_destroy; sr_forget;
		  sr_update;
		  sr_get_supported_types; sr_scan; sr_probe; sr_set_shared;
		  sr_create_new_blob;
		  sr_set_physical_size; sr_set_virtual_allocation; sr_set_physical_utilisation;
		  sr_assert_can_host_ha_statefile;
		  sr_lvhd_stop_using_these_vdis_and_call_script;
		]
      ~contents:
      ([ uid _sr;
	namespace ~name:"name" ~contents:(names oss_since_303 RW;)
      ] @ (allowed_and_current_operations storage_operations) @ [
	field ~ty:(Set(Ref _vdi)) ~qualifier:DynamicRO "VDIs" "all virtual disks known to this storage repository";
	field ~qualifier:DynamicRO ~ty:(Set (Ref _pbd)) "PBDs" "describes how particular hosts can see this storage repository";
	field ~ty:Int ~qualifier:DynamicRO "virtual_allocation" "sum of virtual_sizes of all VDIs in this storage repository (in bytes)";
	field ~ty:Int ~qualifier:DynamicRO "physical_utilisation" "physical space currently utilised on this storage repository (in bytes). Note that for sparse disk formats, physical_utilisation may be less than virtual_allocation";
	field ~ty:Int ~qualifier:StaticRO "physical_size" "total physical size of the repository (in bytes)";
	field ~qualifier:StaticRO "type" "type of the storage repository";
	field ~qualifier:StaticRO "content_type" "the type of the SR's content, if required (e.g. ISOs)";
	field ~qualifier:DynamicRO "shared" ~ty:Bool "true if this SR is (capable of being) shared between multiple hosts";
	field ~ty:(Map(String, String)) "other_config" "additional configuration";
	field  ~in_product_since:rel_orlando ~default_value:(Some (VSet [])) ~ty:(Set String) "tags" "user-specified tags for categorization purposes";
 	field ~ty:Bool ~qualifier:DynamicRO ~in_oss_since:None ~internal_only:true "default_vdi_visibility" "";
	field ~in_oss_since:None ~ty:(Map(String, String)) ~in_product_since:rel_miami ~qualifier:RW "sm_config" "SM dependent data" ~default_value:(Some (VMap []));
	field ~qualifier:DynamicRO ~in_product_since:rel_orlando ~ty:(Map(String, Ref _blob)) ~default_value:(Some (VMap [])) "blobs" "Binary blobs associated with this SR";
      ])
	()

(** XXX: just make this a field and be done with it. Cowardly refusing to change the schema for now. *)
let sm_get_driver_filename = call
   ~name:"get_driver_filename"
   ~in_oss_since:None
   ~in_product_since:rel_orlando
   ~params:[Ref _sm, "self", "The SM to query" ]
   ~result:(String, "The SM's driver_filename field")
   ~doc:"Gets the SM's driver_filename field"
   ()  

let storage_plugin = 
  create_obj ~in_db:true ~in_product_since:rel_rio ~in_oss_since:None ~internal_deprecated_since:None ~persist:PersistEverything ~gen_constructor_destructor:false ~name:_sm ~descr:"A storage manager plugin"
    ~gen_events:true
    ~doccomments:[]
    ~messages:[ ]
    ~contents:
    ([ uid _sm;
       namespace ~name:"name" ~contents:(names None DynamicRO);
       field ~in_oss_since:None ~qualifier:DynamicRO "type" "SR.type";
       field ~in_oss_since:None ~qualifier:DynamicRO "vendor" "Vendor who created this plugin";
       field ~in_oss_since:None ~qualifier:DynamicRO "copyright" "Entity which owns the copyright of this plugin";
       field ~in_oss_since:None ~qualifier:DynamicRO "version" "Version of the plugin";
       field ~in_oss_since:None ~qualifier:DynamicRO "required_api_version" "Minimum SM API version required on the server";
       field ~in_oss_since:None ~qualifier:DynamicRO ~ty:(Map(String,String)) "configuration" "names and descriptions of device config keys";
       field ~in_oss_since:None ~qualifier:DynamicRO ~in_product_since:rel_miami ~ty:(Set(String)) "capabilities" "capabilities of the SM plugin" ~default_value:(Some (VSet []));
       field ~in_product_since:rel_miami ~default_value:(Some (VMap [])) ~ty:(Map(String, String)) "other_config" "additional configuration";
       field ~in_product_since:rel_orlando ~qualifier:DynamicRO ~default_value:(Some (VString "")) ~ty:String "driver_filename" "filename of the storage driver";
     ])
    ()

(* --- rws: removed this after talking to Andy and Julian
let filesystem =
  { name = _filesystem; description = "An on-disk filesystem";
    messages = [];
    contents =
      field "uuid" "globally-unique ID" ::
    let field ?(ty=Int) = field ~qualifier:DynamicRO ~ty in
    [ field "block_size" "block size";
      field "total_blocks" "total blocks on disk";
      field "available_blocks" "blocks available for allocation";
      field "used_blocks" "blocks already in use";
      field "percentage_free" "Percentage of free space left in filesystem";
      field ~ty:String "type" "filesystem type" ] }
*)


(** Each disk is associated with a vdi_type: (a 'style' of disk?) *)
let vdi_type = Enum ("vdi_type", [ "system",    "a disk that may be replaced on upgrade"; 
				   "user",      "a disk that is always preserved on upgrade"; 
				   "ephemeral", "a disk that may be reformatted on upgrade";
				   "suspend",   "a disk that stores a suspend image";
				   "crashdump", "a disk that stores VM crashdump information";
				   "ha_statefile", "a disk used for HA storage heartbeating";
				   "metadata", "a disk used for HA Pool metadata";
				   "redo_log", "a disk used for a general metadata redo-log";
				 ])

let vdi_introduce_params first_rel =
  [
    {param_type=String; param_name="uuid"; param_doc="The uuid of the disk to introduce"; param_release=first_rel; param_default=None};
    {param_type=String; param_name="name_label"; param_doc="The name of the disk record"; param_release=first_rel; param_default=None};
    {param_type=String; param_name="name_description"; param_doc="The description of the disk record"; param_release=first_rel; param_default=None};
    {param_type=Ref _sr; param_name="SR"; param_doc="The SR that the VDI is in"; param_release=first_rel; param_default=None};
    {param_type=vdi_type; param_name="type"; param_doc="The type of the VDI"; param_release=first_rel; param_default=None};
    {param_type=Bool; param_name="sharable"; param_doc="true if this disk may be shared"; param_release=first_rel; param_default=None};
    {param_type=Bool; param_name="read_only"; param_doc="true if this disk may ONLY be mounted read-only"; param_release=first_rel; param_default=None};
    {param_type=Map(String, String); param_name="other_config"; param_doc="additional configuration"; param_release=first_rel; param_default=None};
    {param_type=String; param_name="location"; param_doc="location information"; param_release=first_rel; param_default=None};
    {param_type=Map(String, String); param_name="xenstore_data"; param_doc="Data to insert into xenstore"; param_release=first_rel; param_default=Some (VMap [])};
    {param_type=Map(String, String); param_name="sm_config"; param_doc="Storage-specific config"; param_release=miami_release; param_default=Some (VMap [])};
  ]

(* This used to be called VDI.introduce but it was always an internal call *)
let vdi_pool_introduce = call
  ~name:"pool_introduce"
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~versioned_params:(vdi_introduce_params miami_release)
  ~doc:"Create a new VDI record in the database only"
  ~result:(Ref _vdi, "The ref of the newly created VDI record.")
  ~hide_from_docs:true
    ()

let vdi_db_introduce = { vdi_pool_introduce with msg_name = "db_introduce"; msg_hide_from_docs = false }

let vdi_db_forget = call
  ~name:"db_forget"
  ~in_oss_since:None
  ~params:[Ref _vdi, "vdi", "The VDI to forget about"]
  ~doc:"Removes a VDI record from the database"
  ~in_product_since:rel_miami
  ()

let vdi_introduce = call
  ~name:"introduce"
  ~in_oss_since:None
  ~versioned_params:(vdi_introduce_params rio_release)
  ~doc:"Create a new VDI record in the database only"
  ~result:(Ref _vdi, "The ref of the newly created VDI record.")
  ~errs:[Api_errors.sr_operation_not_supported]
  ~in_product_since:rel_miami
  ()

let vdi_forget = call
  ~name:"forget"
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~params:[Ref _vdi, "vdi", "The VDI to forget about"]
  ~doc:"Removes a VDI record from the database"
  ()

let vdi_force_unlock = call
  ~name:"force_unlock"
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~internal_deprecated_since:rel_miami
  ~params:[Ref _vdi, "vdi", "The VDI to forcibly unlock"]
  ~doc:"Steals the lock on this VDI and leaves it unlocked. This function is extremely dangerous. This call is deprecated."
  ~hide_from_docs:true
  ()

let vdi_update = call
  ~name:"update"
  ~in_oss_since:None
  ~params:[Ref _vdi, "vdi", "The VDI whose stats (eg size) should be updated" ]
  ~doc:"Ask the storage backend to refresh the fields in the VDI object"
  ~errs:[Api_errors.sr_operation_not_supported]
  ~in_product_since:rel_symc
  ()

let vdi_operations =
  Enum ("vdi_operations", 
	[ "scan", "Scanning backends for new or deleted VDIs";
	  "clone", "Cloning the VDI";
	  "copy", "Copying the VDI";
	  "resize", "Resizing the VDI";
	  "resize_online", "Resizing the VDI which may or may not be online";
	  "snapshot", "Snapshotting the VDI";
	  "destroy", "Destroying the VDI";
	  "forget", "Forget about the VDI";
	  "update", "Refreshing the fields of the VDI";
	  "force_unlock", "Forcibly unlocking the VDI";
	  "generate_config", "Generating static configuration";
	  "blocked", "Operations on this VDI are temporarily blocked";
	])

let vdi_set_missing = call
  ~name:"set_missing"
  ~in_oss_since:None
  ~in_product_since:rel_miami
   ~params:[Ref _vdi, "self", "The VDI to modify";
 	   Bool, "value", "The new value of the VDI's missing field"]
   ~doc:"Sets the VDI's missing field"
  ~flags:[`Session]
   ()  

 let vdi_set_read_only = call
   ~name:"set_read_only"
   ~in_oss_since:None
   ~in_product_since:rel_rio
   ~params:[Ref _vdi, "self", "The VDI to modify";
 	   Bool, "value", "The new value of the VDI's read_only field"]
  ~flags:[`Session]
   ~doc:"Sets the VDI's read_only field"
   ()

 let vdi_set_sharable = call
   ~name:"set_sharable"
   ~in_oss_since:None
   ~in_product_since:rel_george
   ~params:[Ref _vdi, "self", "The VDI to modify";
 	   Bool, "value", "The new value of the VDI's sharable field"]
  ~flags:[`Session]
   ~doc:"Sets the VDI's sharable field"
   ()

 let vdi_set_managed = call
   ~name:"set_managed"
   ~in_oss_since:None
	 ~in_product_since:rel_rio
   ~params:[Ref _vdi, "self", "The VDI to modify";
 	   Bool, "value", "The new value of the VDI's managed field"]
  ~flags:[`Session]
   ~doc:"Sets the VDI's managed field"
   ()
 
 let vdi_set_virtual_size = call
   ~name:"set_virtual_size"
   ~in_oss_since:None
   ~in_product_since:rel_miami
   ~params:[Ref _vdi, "self", "The VDI to modify";
 	   Int, "value", "The new value of the VDI's virtual size"]
  ~flags:[`Session]
   ~doc:"Sets the VDI's virtual_size field"
   ()

 let vdi_set_physical_utilisation = call
   ~name:"set_physical_utilisation"
   ~in_oss_since:None
   ~in_product_since:rel_miami
   ~params:[Ref _vdi, "self", "The VDI to modify";
 	   Int, "value", "The new value of the VDI's physical utilisation"]
  ~flags:[`Session]
   ~doc:"Sets the VDI's physical_utilisation field"
   ()

(** An API call for debugging and testing only *)
 let vdi_generate_config = call
   ~name:"generate_config"
   ~in_oss_since:None
   ~in_product_since:rel_orlando
   ~params:[Ref _host, "host", "The host on which to generate the configuration";
	    Ref _vdi, "vdi", "The VDI to generate the configuration for" ]
   ~result:(String, "The generated static configuration")
   ~doc:"Internal function for debugging only"
   ~hide_from_docs:true
   ()

(** A virtual disk *)
let vdi =
    create_obj ~in_db:true ~in_product_since:rel_rio ~in_oss_since:oss_since_303 ~internal_deprecated_since:None ~persist:PersistEverything ~gen_constructor_destructor:true ~name:_vdi ~descr:"A virtual disk image"
      ~gen_events:true
      ~doccomments:[] 
      ~messages:[vdi_snapshot; vdi_clone; vdi_resize; 
		 vdi_resize_online;
		 vdi_introduce; vdi_pool_introduce;
		 vdi_db_introduce; vdi_db_forget;
		 vdi_update;
		 vdi_copy;
		 vdi_force_unlock; vdi_set_managed;
		 vdi_forget;
		 vdi_set_sharable;
		 vdi_set_read_only;
		 vdi_set_missing;
		 vdi_set_virtual_size;
		 vdi_set_physical_utilisation;
		 vdi_generate_config;
		]
      ~contents:
      ([ uid _vdi;
	namespace ~name:"name" ~contents:(names oss_since_303 RW);
      ] @ (allowed_and_current_operations vdi_operations) @ [
	field ~qualifier:StaticRO ~ty:(Ref _sr) "SR" "storage repository in which the VDI resides";
  field ~qualifier:DynamicRO ~ty:(Set (Ref _vbd)) "VBDs" "list of vbds that refer to this disk";
	field ~qualifier:DynamicRO ~ty:(Set (Ref _crashdump)) "crash_dumps" "list of crash dumps that refer to this disk";
	field ~qualifier:StaticRO ~ty:Int "virtual_size" "size of disk as presented to the guest (in bytes). Note that, depending on storage backend type, requested size may not be respected exactly";
	field ~qualifier:DynamicRO ~ty:Int "physical_utilisation" "amount of physical space that the disk image is currently taking up on the storage repository (in bytes)";
	field ~qualifier:StaticRO ~ty:vdi_type "type" "type of the VDI";
	field ~qualifier:StaticRO ~ty:Bool "sharable" "true if this disk may be shared";
	field ~qualifier:StaticRO ~ty:Bool "read_only" "true if this disk may ONLY be mounted read-only";
	field  ~ty:(Map(String, String)) "other_config" "additional configuration" ;
	field ~qualifier:DynamicRO ~ty:Bool "storage_lock" "true if this disk is locked at the storage level";
	(* XXX: location field was in the database in rio, now API in miami *)
	field ~in_oss_since:None ~in_product_since:rel_miami ~ty:String ~qualifier:DynamicRO ~default_value:(Some (VString "")) "location" "location information";
	field ~in_oss_since:None ~ty:Bool ~qualifier:DynamicRO "managed" "";
	field ~in_oss_since:None ~ty:Bool ~qualifier:DynamicRO "missing" "true if SR scan operation reported this VDI as not present on disk";
	field ~in_oss_since:None ~ty:(Ref _vdi) ~qualifier:DynamicRO "parent" "References the parent disk, if this VDI is part of a chain";
	field ~in_oss_since:None ~ty:(Map(String, String)) ~in_product_since:rel_miami ~qualifier:RW "xenstore_data" "data to be inserted into the xenstore tree (/local/domain/0/backend/vbd/<domid>/<device-id>/sm-data) after the VDI is attached. This is generally set by the SM backends on vdi_attach." ~default_value:(Some (VMap []));
	field ~in_oss_since:None ~ty:(Map(String, String)) ~in_product_since:rel_miami ~qualifier:RW "sm_config" "SM dependent data" ~default_value:(Some (VMap []));

	field ~in_product_since:rel_orlando ~default_value:(Some (VBool false))          ~qualifier:DynamicRO ~ty:Bool             "is_a_snapshot" "true if this is a snapshot.";
	field ~in_product_since:rel_orlando ~default_value:(Some (VRef ""))              ~qualifier:DynamicRO ~ty:(Ref _vdi)       "snapshot_of" "Ref pointing to the VDI this snapshot is of.";
	field ~in_product_since:rel_orlando                                              ~qualifier:DynamicRO ~ty:(Set (Ref _vdi)) "snapshots" "List pointing to all the VDIs snapshots.";
	field ~in_product_since:rel_orlando ~default_value:(Some (VDateTime Date.never)) ~qualifier:DynamicRO ~ty:DateTime         "snapshot_time" "Date/time when this snapshot was created.";
	field  ~in_product_since:rel_orlando ~default_value:(Some (VSet [])) ~ty:(Set String) "tags" "user-specified tags for categorization purposes";
      ])
	()

(** Virtual disk interfaces have a mode parameter: *)
let vbd_mode = Enum ("vbd_mode", [ "RO", "only read-only access will be allowed";
				   "RW", "read-write access will be allowed" ])

let vbd_type = Enum ("vbd_type",
		     [ "CD", "VBD will appear to guest as CD"; 
		       "Disk", "VBD will appear to guest as disk" ])

let vbd_operations =
  Enum ("vbd_operations", 
	[ "attach", "Attempting to attach this VBD to a VM";
	  "eject", "Attempting to eject the media from this VBD";
	  "insert", "Attempting to insert new media into this VBD";
	  "plug", "Attempting to hotplug this VBD";
	  "unplug", "Attempting to hot unplug this VBD";
	  "unplug_force", "Attempting to forcibly unplug this VBD";
	  "pause", "Attempting to pause a block device backend";
	  "unpause", "Attempting to unpause a block device backend";
	])

(** A virtual disk interface *)
let vbd =
  create_obj ~in_db:true ~in_product_since:rel_rio ~in_oss_since:oss_since_303 ~internal_deprecated_since:None ~persist:PersistEverything ~gen_constructor_destructor:true ~name:_vbd ~descr:"A virtual block device"
    ~gen_events:true
      ~doccomments:[]
      ~messages: [ vbd_eject; vbd_insert; vbd_plug; vbd_unplug; vbd_unplug_force; vbd_unplug_force_no_safety_check; vbd_assert_attachable;
		   vbd_pause; vbd_unpause;
		 ]
      ~contents:
    ([ uid _vbd;
     ] @ (allowed_and_current_operations vbd_operations) @ [
       field ~qualifier:StaticRO ~ty:(Ref _vm) "VM" "the virtual machine"; 
       field ~qualifier:StaticRO ~ty:(Ref _vdi) "VDI" "the virtual disk";

       field ~qualifier:DynamicRO "device" "device seen by the guest e.g. hda1";
       field "userdevice" "user-friendly device name e.g. 0,1,2,etc.";
       field ~ty:Bool "bootable" "true if this VBD is bootable";
       field ~ty:vbd_mode "mode" "the mode the VBD should be mounted with";
       field ~ty:vbd_type "type" "how the VBD will appear to the guest (e.g. disk or CD)";
       field ~in_oss_since:None ~in_product_since:rel_miami ~ty:Bool ~default_value:(Some (VBool true))
	 "unpluggable" "true if this VBD will support hot-unplug";
       field ~qualifier:DynamicRO ~ty:Bool "storage_lock" "true if a storage level lock was acquired";
       field ~qualifier:StaticRO ~ty:Bool "empty" "if true this represents an empty drive";
       field ~in_oss_since:None ~internal_only:true ~qualifier:DynamicRO ~ty:Bool "reserved" "true if the VBD is reserved pending a reboot/migrate";
       field ~ty:(Map(String, String)) "other_config" "additional configuration";
 ]
     @ device_status_fields @
       [ namespace ~name:"qos" ~contents:(qos "VBD"); ] @
       [ field ~qualifier:DynamicRO ~ty:(Ref _vbd_metrics) "metrics" "metrics associated with this VBD"; ])
	()

let vbd_metrics = 
    create_obj ~in_db:true ~in_product_since:rel_rio ~in_oss_since:oss_since_303 ~internal_deprecated_since:None ~persist:PersistNothing ~gen_constructor_destructor:false ~name:_vbd_metrics ~descr:"The metrics associated with a virtual block device"
      ~gen_events:true
      ~doccomments:[]
      ~messages:[] ~contents:
      [ uid _vbd_metrics;
	namespace ~name:"io" ~contents:iobandwidth;
	field ~qualifier:DynamicRO ~ty:DateTime "last_updated" "Time at which this information was last updated";
	field ~in_product_since:rel_orlando ~default_value:(Some (VMap [])) ~ty:(Map(String, String)) "other_config" "additional configuration";
      ]
	()

let crashdump_destroy = call
  ~name:"destroy"
  ~in_product_since:rel_rio
  ~doc:"Destroy the specified crashdump"
  ~params:[Ref _crashdump, "self", "The crashdump to destroy"]
  ()


(** A crashdump for a particular VM, stored in a particular VDI *)
let crashdump =
  create_obj ~in_db:true ~in_product_since:rel_rio ~in_oss_since:None ~internal_deprecated_since:None ~persist:PersistEverything ~gen_constructor_destructor:false ~name:_crashdump ~descr:"A VM crashdump"
    ~gen_events:true
    ~doccomments:[] 
    ~messages: [crashdump_destroy]
    ~contents:
    ([ uid _crashdump;
       field ~qualifier:StaticRO ~ty:(Ref _vm) "VM" "the virtual machine";
       field ~qualifier:StaticRO ~ty:(Ref _vdi) "VDI" "the virtual disk";
       field ~in_product_since:rel_miami ~default_value:(Some (VMap [])) ~ty:(Map(String, String)) "other_config" "additional configuration";      
     ])
	()

let pool_enable_ha = call
  ~in_product_since:rel_miami
  ~name:"enable_ha"
  ~in_oss_since:None
  ~params:[
    Set(Ref _sr), "heartbeat_srs", "Set of SRs to use for storage heartbeating.";
    Map(String, String), "configuration", "Detailed HA configuration to apply"]
  ~doc:"Turn on High Availability mode"
  ()

let pool_disable_ha = call
  ~in_product_since:rel_miami
  ~name:"disable_ha"
  ~in_oss_since:None
  ~params:[]
  ~doc:"Turn off High Availability mode"
  ()

let pool_sync_database = call
  ~name:"sync_database"
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~params:[]
  ~doc:"Forcibly synchronise the database now"
  ()

let pool_designate_new_master = call
  ~in_product_since:rel_miami
  ~name:"designate_new_master"
  ~in_oss_since:None
  ~params:[Ref _host, "host", "The host who should become the new master"]
  ~doc:"Perform an orderly handover of the role of master to the referenced host."
  ()

let pool_join = call
  ~name:"join"
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~params:[String, "master_address", "The hostname of the master of the pool to join";
	   String, "master_username", "The username of the master (for initial authentication)";
	   String, "master_password", "The password for the master (for initial authentication)";
	  ]
  ~errs:[Api_errors.pool_joining_host_cannot_contain_shared_SRs]
  ~doc:"Instruct host to join a new pool"
    ()

let pool_join_force = call
  ~name:"join_force"
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~params:[String, "master_address", "The hostname of the master of the pool to join";
	   String, "master_username", "The username of the master (for initial authentication)";
	   String, "master_password", "The password for the master (for initial authentication)";
	  ]
  ~doc:"Instruct host to join a new pool"
    ()


let pool_slave_reset_master = call ~flags:[`Session]
  ~name:"emergency_reset_master"
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~params:[
	    String, "master_address", "The hostname of the master";
	  ]
  ~doc:"Instruct a slave already in a pool that the master has changed"
    ()

let pool_transition_to_master = call ~flags:[`Session]
  ~name:"emergency_transition_to_master"
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~params:[]
  ~doc:"Instruct host that's currently a slave to transition to being master"
    ()

let pool_recover_slaves = call
  ~name:"recover_slaves"
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~params:[]
  ~result:(Set (Ref _host), "list of hosts whose master address were succesfully reset")
  ~doc:"Instruct a pool master, M, to try and contact its slaves and, if slaves are in emergency mode, reset their master address to M."
  ()
  
let pool_eject = call
  ~name:"eject"
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~params:[Ref _host, "host", "The host to eject"]
  ~doc:"Instruct a pool master to eject a host from the pool"
    ()

let pool_initial_auth = call
  ~name:"initial_auth"
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~params:[]
  ~result:(String, "")
  ~doc:"Internal use only"
  ~hide_from_docs:true
    ()

let pool_create_VLAN_from_PIF = call
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~name:"create_VLAN_from_PIF"
  ~doc:"Create a pool-wide VLAN by taking the PIF."
  ~params:[Ref _pif, "pif", "physical interface on any particular host, that identifies the PIF on which to create the (pool-wide) VLAN interface";
	   Ref _network, "network", "network to which this interface should be connected";
	   Int, "VLAN", "VLAN tag for the new interface"]
  ~result:(Set (Ref _pif), "The references of the created PIF objects")
  ~errs:[Api_errors.vlan_tag_invalid]
  ()

(* !! THIS IS BROKEN; it takes a device name which in the case of a bond is not homogeneous across all pool hosts.
      See CA-22613. !! *)
let pool_create_VLAN = call
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~name:"create_VLAN"
  ~doc:"Create PIFs, mapping a network to the same physical interface/VLAN on each host. This call is deprecated: use Pool.create_VLAN_from_PIF instead."
  ~params:[String, "device", "physical interface on which to create the VLAN interface";
	   Ref _network, "network", "network to which this interface should be connected";
	   Int, "VLAN", "VLAN tag for the new interface"]
  ~result:(Set (Ref _pif), "The references of the created PIF objects")
  ~errs:[Api_errors.vlan_tag_invalid]
  ()


let hello_return = Enum("hello_return", [
			      "ok", "";
			      "unknown_host", "";
			      "cannot_talk_back", ""
			    ])

let pool_hello = call
  ~name:"hello"
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~params:[String, "host_uuid", "";
	   String, "host_address", ""
	  ]
  ~result:(hello_return, "")
  ~doc:"Internal use only"
  ~hide_from_docs:true
  ()

let pool_slave_network_report = call
  ~name:"slave_network_report"
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~doc:"Internal use only"
  ~params:[Map (String, String), "phydevs", "(device,bridge) pairs of physical NICs on slave";
	   Map (String, String), "dev_to_mac", "(device,mac) pairs of physical NICs on slave";
	   Map (String, Int), "dev_to_mtu", "(device,mtu) pairs of physical NICs on slave";
	   Ref _host, "slave_host", "the host that the PIFs will be attached to when created"
	  ]
  ~result:(Set(Ref _pif), "refs for pifs corresponding to device list")
  ~hide_from_docs:true
  ()

let pool_ping_slave = call ~flags:[`Session]
  ~name:"is_slave"
  ~in_oss_since:None
  ~in_product_since:rel_rio
  ~params:[Ref _host, "host", ""]
  ~doc:"Internal use only"
  ~result:(Bool, "returns false if pinged host is master [indicating critical error condition]; true if pinged host is slave")
  ~hide_from_docs:true
  ()

let pool_ha_prevent_restarts_for = call ~flags:[`Session]
  ~name:"ha_prevent_restarts_for"
  ~in_product_since:rel_orlando_update_1
  ~doc:"When this call returns the VM restart logic will not run for the requested number of seconds. If the argument is zero then the restart thread is immediately unblocked"
  ~params:[Int, "seconds", "The number of seconds to block the restart thread for"]
  ()

let pool_ha_failover_plan_exists = call ~flags:[`Session]
  ~name:"ha_failover_plan_exists"
  ~in_product_since:rel_orlando
  ~doc:"Returns true if a VM failover plan exists for up to 'n' host failures"
  ~params:[Int, "n", "The number of host failures to plan for" ]
  ~result:(Bool, "true if a failover plan exists for the supplied number of host failures")
  ()

let pool_ha_compute_max_host_failures_to_tolerate = call ~flags:[`Session]
  ~name:"ha_compute_max_host_failures_to_tolerate"
  ~in_product_since:rel_orlando
  ~doc:"Returns the maximum number of host failures we could tolerate before we would be unable to restart configured VMs"
  ~params:[]
  ~result:(Int, "maximum value for ha_host_failures_to_tolerate given current configuration")
  ()

let pool_ha_compute_hypothetical_max_host_failures_to_tolerate = call ~flags:[`Session]
  ~name:"ha_compute_hypothetical_max_host_failures_to_tolerate"
  ~in_product_since:rel_orlando
  ~doc:"Returns the maximum number of host failures we could tolerate before we would be unable to restart the provided VMs"
  ~params:[ Map(Ref _vm, String), "configuration", "Map of protected VM reference to restart priority" ]
  ~result:(Int, "maximum value for ha_host_failures_to_tolerate given provided configuration")
  ()

let pool_ha_compute_vm_failover_plan = call ~flags:[`Session]
  ~name:"ha_compute_vm_failover_plan"
  ~in_product_since:rel_orlando
  ~doc:"Return a VM failover plan assuming a given subset of hosts fail"
  ~params:[Set(Ref _host), "failed_hosts", "The set of hosts to assume have failed";
	   Set(Ref _vm), "failed_vms", "The set of VMs to restart" ]
  ~result:(Map(Ref _vm, Map(String, String)), "VM failover plan: a map of VM to host to restart the host on")
  ()

let pool_create_new_blob = call
  ~name: "create_new_blob"
  ~in_product_since:rel_orlando
  ~doc:"Create a placeholder for a named binary blob of data that is associated with this pool"
  ~params:[Ref _pool, "pool", "The pool";
	   String, "name", "The name associated with the blob";
	   String, "mime_type", "The mime type for the data. Empty string translates to application/octet-stream";]
  ~result:(Ref _blob, "The reference of the blob, needed for populating its data")
  ()

let pool_set_ha_host_failures_to_tolerate = call
  ~name:"set_ha_host_failures_to_tolerate"
  ~in_product_since:rel_orlando
  ~doc:"Set the maximum number of host failures to consider in the HA VM restart planner"
  ~params:[Ref _pool, "self", "The pool";
	   Int, "value", "New number of host failures to consider"]
  ()

let pool_ha_schedule_plan_recomputation = call
  ~name:"ha_schedule_plan_recomputation"
  ~in_product_since:rel_orlando
  ~doc:"Signal that the plan should be recomputed (eg a host has come online)"
  ~params:[]
  ~hide_from_docs:true
  ~pool_internal:true
  ()

let pool_enable_binary_storage = call
  ~name:"enable_binary_storage"
  ~in_product_since:rel_orlando
  ~hide_from_docs:true
  ~doc:"Enable the storage of larger objects, such as RRDs, messages and binary blobs across all hosts in the pool"
  ~params:[]
  ()

let pool_disable_binary_storage = call
  ~name:"disable_binary_storage"
  ~in_product_since:rel_orlando
  ~hide_from_docs:true
  ~doc:"Disable the storage of larger objects, such as RRDs, messages and binary blobs across all hosts in the pool. This will destroy all of these objects where they exist."
  ~params:[]
  ()

let pool_enable_external_auth = call ~flags:[`Session]
  ~name:"enable_external_auth"
  ~in_oss_since:None
  ~in_product_since:rel_george
  ~params:[
    Ref _pool, "pool", "The pool whose external authentication should be enabled"; 
    Map (String,String), "config", "A list of key-values containing the configuration data" ; 
    String, "service_name", "The name of the service" ; 
    String, "auth_type", "The type of authentication (e.g. AD for Active Directory)" 
    ]
  ~doc:"This call enables external authentication on all the hosts of the pool"
  ()

let pool_disable_external_auth = call ~flags:[`Session]
  ~name:"disable_external_auth"
  ~in_oss_since:None
  ~in_product_since:rel_george
  ~versioned_params:[
    {param_type=Ref _pool; param_name="pool"; param_doc="The pool whose external authentication should be disabled"; param_release=george_release; param_default=None};
    {param_type=Map (String, String); param_name="config"; param_doc="Optional parameters as a list of key-values containing the configuration data"; param_release=george_release; param_default=Some (VMap [])}
    ]
  ~doc:"This call disables external authentication on all the hosts of the pool"
  ()

let pool_detect_nonhomogeneous_external_auth = call ~flags:[`Session]
  ~name:"detect_nonhomogeneous_external_auth"
  ~in_oss_since:None
  ~in_product_since:rel_george
  ~params:[
    Ref _pool, "pool", "The pool where to detect non-homogeneous external authentication configuration"; 
    ]
  ~doc:"This call asynchronously detects if the external authentication configuration in any slave is different from that in the master and raises appropriate alerts"
  ()

let pool_initialize_wlb = call
  ~name:"initialize_wlb"
  ~in_product_since:rel_george
  ~doc:"Initializes workload balancing monitoring on this pool with the specified wlb server"
  ~params:[String, "wlb_url", "The ip address and port to use when accessing the wlb server";
    String, "wlb_username", "The username used to authenticate with the wlb server";
    String, "wlb_password", "The password used to authenticate with the wlb server";
    String, "xenserver_username", "The usernamed used by the wlb server to authenticate with the xenserver";
    String, "xenserver_password", "The password used by the wlb server to authenticate with the xenserver"]
   ()

let pool_deconfigure_wlb = call
  ~name:"deconfigure_wlb"
  ~in_product_since:rel_george
  ~doc:"Permanently deconfigures workload balancing monitoring on this pool"
  ~params:[]
   ()

let pool_send_wlb_configuration = call
  ~name:"send_wlb_configuration"
  ~in_product_since:rel_george
  ~doc:"Sets the pool optimization criteria for the workload balancing server"
  ~params:[Map(String, String), "config", "The configuration to use in optimizing this pool"]
   ()
 
let pool_retrieve_wlb_configuration = call
  ~name:"retrieve_wlb_configuration"
  ~in_product_since:rel_george
  ~doc:"Retrieves the pool optimization criteria from the workload balancing server"
  ~params:[]
  ~result:(Map(String,String), "The configuration used in optimizing this pool")
   ()
   
let pool_retrieve_wlb_recommendations = call
  ~name:"retrieve_wlb_recommendations"
  ~in_product_since:rel_george
  ~doc:"Retrieves vm migrate recommendations for the pool from the workload balancing server"
  ~params:[]
  ~result:(Map(Ref _vm,Set(String)), "The list of vm migration recommendations")
   ()
   
let pool_send_test_post = call
  ~name:"send_test_post"
  ~in_product_since:rel_george
  ~doc:"Send the given body to the given host and port, using HTTPS, and print the response.  This is used for debugging the SSL layer."
  ~params:[(String, "host", ""); (Int, "port", ""); (String, "body", "")]
  ~result:(String, "The response")
   ()
   
let pool_certificate_install = call
  ~in_oss_since:None
  ~in_product_since:rel_george
  ~name:"certificate_install"
  ~doc:"Install an SSL certificate pool-wide."
  ~params:[String, "name", "A name to give the certificate";
	   String, "cert", "The certificate"]
  ()

let pool_certificate_uninstall = call
  ~in_oss_since:None
  ~in_product_since:rel_george
  ~name:"certificate_uninstall"
  ~doc:"Remove an SSL certificate."
  ~params:[String, "name", "The certificate name"]
  ()

let pool_certificate_list = call
  ~in_oss_since:None
  ~in_product_since:rel_george
  ~name:"certificate_list"
  ~doc:"List all installed SSL certificates."
  ~result:(Set(String),"All installed certificates")
  ()

let pool_crl_install = call
  ~in_oss_since:None
  ~in_product_since:rel_george
  ~name:"crl_install"
  ~doc:"Install an SSL certificate revocation list, pool-wide."
  ~params:[String, "name", "A name to give the CRL";
	   String, "cert", "The CRL"]
  ()

let pool_crl_uninstall = call
  ~in_oss_since:None
  ~in_product_since:rel_george
  ~name:"crl_uninstall"
  ~doc:"Remove an SSL certificate revocation list."
  ~params:[String, "name", "The CRL name"]
  ()

let pool_crl_list = call
  ~in_oss_since:None
  ~in_product_since:rel_george
  ~name:"crl_list"
  ~doc:"List all installed SSL certificate revocation lists."
  ~result:(Set(String), "All installed CRLs")
  ()

let pool_certificate_sync = call
  ~in_oss_since:None
  ~in_product_since:rel_george
  ~name:"certificate_sync"
  ~doc:"Sync SSL certificates from master to slaves."
  ()
  
let pool_enable_redo_log = call
  ~in_oss_since:None
  ~in_product_since:rel_midnight_ride
  ~name:"enable_redo_log"
  ~params:[Ref _sr, "sr", "SR to hold the redo log."]
  ~doc:"Enable the redo log on the given SR and start using it, unless HA is enabled."
  ()
  
let pool_disable_redo_log = call
  ~in_oss_since:None
  ~in_product_since:rel_midnight_ride
  ~name:"disable_redo_log"
  ~doc:"Disable the redo log if in use, unless HA is enabled."
  ()

(** A pool class *)
let pool =
  create_obj ~in_db:true ~in_product_since:rel_rio ~in_oss_since:None ~internal_deprecated_since:None ~persist:PersistEverything ~gen_constructor_destructor:false ~name:_pool ~descr:"Pool-wide information"
    ~gen_events:true
    ~doccomments:[]
    ~messages: [pool_join; pool_join_force; pool_eject; pool_initial_auth; pool_transition_to_master; pool_slave_reset_master;
		pool_recover_slaves; pool_hello; pool_ping_slave; pool_create_VLAN; pool_create_VLAN_from_PIF; pool_slave_network_report;
	       pool_enable_ha; pool_disable_ha;
	       pool_sync_database;
	       pool_designate_new_master;
	       pool_ha_prevent_restarts_for;
	       pool_ha_failover_plan_exists;
	       pool_ha_compute_max_host_failures_to_tolerate;
	       pool_ha_compute_hypothetical_max_host_failures_to_tolerate;
	       pool_ha_compute_vm_failover_plan;
	       pool_set_ha_host_failures_to_tolerate;
	       pool_create_new_blob;
	       pool_ha_schedule_plan_recomputation;
	       pool_enable_binary_storage;
	       pool_disable_binary_storage;
	       pool_enable_external_auth;
	       pool_disable_external_auth;
	       pool_detect_nonhomogeneous_external_auth;
	       pool_initialize_wlb;
	       pool_deconfigure_wlb;
	       pool_send_wlb_configuration;
	       pool_retrieve_wlb_configuration;
	       pool_retrieve_wlb_recommendations;
	       pool_send_test_post;
	       pool_certificate_install;
	       pool_certificate_uninstall;
	       pool_certificate_list;
	       pool_crl_install;
	       pool_crl_uninstall;
	       pool_crl_list;
	       pool_certificate_sync;
	       pool_enable_redo_log;
	       pool_disable_redo_log;
	       ]
    ~contents:
    [uid ~in_oss_since:None _pool;
     field ~in_oss_since:None ~qualifier:RW ~ty:String "name_label" "Short name";
     field ~in_oss_since:None ~qualifier:RW ~ty:String "name_description" "Description";
     field ~in_oss_since:None ~qualifier:DynamicRO ~ty:(Ref _host) "master" "The host that is pool master";
     field ~in_oss_since:None ~qualifier:RW ~ty:(Ref _sr) "default_SR" "Default SR for VDIs";
     field ~in_oss_since:None ~qualifier:RW ~ty:(Ref _sr) "suspend_image_SR" "The SR in which VDIs for suspend images are created";
     field ~in_oss_since:None ~qualifier:RW ~ty:(Ref _sr) "crash_dump_SR" "The SR in which VDIs for crash dumps are created";
     field ~in_oss_since:None ~ty:(Map(String, String)) "other_config" "additional configuration";
     field ~in_oss_since:None ~in_product_since:rel_orlando ~qualifier:DynamicRO ~ty:Bool ~default_value:(Some (VBool false)) "ha_enabled" "true if HA is enabled on the pool, false otherwise";
     field ~in_oss_since:None ~in_product_since:rel_orlando ~qualifier:DynamicRO ~ty:(Map(String, String)) ~default_value:(Some (VMap [])) "ha_configuration" "The current HA configuration";
     field ~in_oss_since:None ~in_product_since:rel_orlando ~qualifier:DynamicRO ~ty:(Set String) ~default_value:(Some (VSet [])) "ha_statefiles" "HA statefile VDIs in use";
     field ~in_oss_since:None ~in_product_since:rel_orlando ~qualifier:DynamicRO ~ty:Int ~default_value:(Some (VInt 0L)) "ha_host_failures_to_tolerate" "Number of host failures to tolerate before the Pool is declared to be overcommitted";
     field ~in_oss_since:None ~in_product_since:rel_orlando ~qualifier:DynamicRO ~ty:Int ~default_value:(Some (VInt 0L)) "ha_plan_exists_for" "Number of future host failures we have managed to find a plan for. Once this reaches zero any future host failures will cause the failure of protected VMs.";
     field ~in_oss_since:None ~in_product_since:rel_orlando ~qualifier:RW ~ty:Bool ~default_value:(Some (VBool false)) "ha_allow_overcommit" "If set to false then operations which would cause the Pool to become overcommitted will be blocked.";
     field ~in_oss_since:None ~in_product_since:rel_orlando ~qualifier:DynamicRO ~ty:Bool ~default_value:(Some (VBool false)) "ha_overcommitted" "True if the Pool is considered to be overcommitted i.e. if there exist insufficient physical resources to tolerate the configured number of host failures";
     field ~qualifier:DynamicRO ~in_product_since:rel_orlando ~ty:(Map(String, Ref _blob)) ~default_value:(Some (VMap [])) "blobs" "Binary blobs associated with this pool";
     field  ~in_product_since:rel_orlando ~default_value:(Some (VSet [])) ~ty:(Set String) "tags" "user-specified tags for categorization purposes";
     field  ~in_product_since:rel_orlando ~default_value:(Some (VMap [])) ~ty:(Map(String, String)) "gui_config" "gui-specific configuration for pool";
     field ~in_product_since:rel_george ~qualifier:DynamicRO ~ty:String ~default_value:(Some (VString "")) "wlb_url" "Url for the configured workload balancing host";
     field ~in_product_since:rel_george ~qualifier:DynamicRO ~ty:String ~default_value:(Some (VString "")) "wlb_username" "Username for accessing the workload balancing host";
     field ~in_product_since:rel_george ~internal_only:true ~qualifier:DynamicRO ~ty:String ~default_value:(Some (VString "")) "wlb_password" "Password for accessing the workload balancing host";
     field ~in_product_since:rel_george ~qualifier:RW ~ty:Bool ~default_value:(Some (VBool false)) "wlb_enabled" "true if workload balancing is enabled on the pool, false otherwise";
     field ~in_product_since:rel_george ~qualifier:RW ~ty:Bool ~default_value:(Some (VBool false)) "wlb_verify_cert" "true if communication with the WLB server should enforce SSL certificate verification.";
     field ~in_oss_since:None ~in_product_since:rel_midnight_ride ~qualifier:DynamicRO ~ty:Bool ~default_value:(Some (VBool false)) "redo_log_enabled" "true a redo-log is to be used other than when HA is enabled, false otherwise";
     field ~in_oss_since:None ~in_product_since:rel_midnight_ride ~qualifier:DynamicRO ~ty:(Ref _vdi) ~default_value:(Some (VRef (Ref.string_of Ref.null))) "redo_log_vdi" "indicates the VDI to use for the redo-log other than when HA is enabled";
    ]
	()

(** Auth class *)
let auth_get_subject_identifier = call ~flags:[`Session]
  ~name:"get_subject_identifier"
  ~in_oss_since:None
  ~in_product_since:rel_george
  ~params:[
    (*Ref _auth, "auth", "???";*)
    String, "subject_name", "The human-readable subject_name, such as a username or a groupname" ; 
    ]
  ~result:(String, "the subject_identifier obtained from the external directory service")
  ~doc:"This call queries the external directory service to obtain the subject_identifier as a string from the human-readable subject_name"
  ()

let auth_get_subject_information_from_identifier = call ~flags:[`Session]
  ~name:"get_subject_information_from_identifier"
  ~in_oss_since:None
  ~in_product_since:rel_george
  ~params:[
    String, "subject_identifier", "A string containing the subject_identifier, unique in the external directory service"
    ]
  ~result:(Map(String,String), "key-value pairs containing at least a key called subject_name")
  ~doc:"This call queries the external directory service to obtain the user information (e.g. username, organization etc) from the specified subject_identifier"
  ()

let auth_get_group_membership = call ~flags:[`Session]
  ~name:"get_group_membership"
  ~in_oss_since:None
  ~in_product_since:rel_george
  ~params:[
    String, "subject_identifier", "A string containing the subject_identifier, unique in the external directory service"
    ]
  ~result:(Set(String), "set of subject_identifiers that provides the group membership of subject_identifier passed as argument, it contains, recursively, all groups a subject_identifier is member of.")
  ~doc:"This calls queries the external directory service to obtain the transitively-closed set of groups that the the subject_identifier is member of."
  ()

let auth =
  create_obj ~in_db:false ~in_product_since:rel_george ~in_oss_since:None ~internal_deprecated_since:None ~persist:PersistNothing ~gen_constructor_destructor:false ~name:_auth ~descr:"Management of remote authentication services"
    ~gen_events:false
    ~doccomments:[]
    ~messages: [auth_get_subject_identifier;
      auth_get_subject_information_from_identifier;
      auth_get_group_membership;]
    ~contents:[]
    ()

(** Subject class *)
let subject_create = call ~flags:[`Session]
  ~name:"create"
  ~in_oss_since:None
  ~in_product_since:rel_midnight_ride
  ~params:[
    String, "subject_identifier", "the subject identifier, unique in the external directory service" ; 
    Map(String, String), "other_config", "additional configuration" ;
    (*new subjects must not have roles*)
    ]
  ~result:(Ref _subject, "The new subject just created")
  ~doc:"This call adds a new role to a subject"
  ()
let subject_destroy = call ~flags:[`Session]
  ~name:"destroy"
  ~in_oss_since:None
  ~in_product_since:rel_midnight_ride
  ~params:[
    Ref _subject, "self", "The subject to be destroyed"
    ]
  ~doc:"This call adds a new role to a subject"
  ()
let subject_add_to_roles = call ~flags:[`Session]
  ~name:"add_to_roles"
  ~in_oss_since:None
  ~in_product_since:rel_midnight_ride
  ~params:[
    Ref _subject, "self", "The subject who we want to add the role to";
    Ref _role, "role", "The unique role reference" ; 
    ]
  ~doc:"This call adds a new role to a subject"
  ()
let subject_remove_from_roles = call ~flags:[`Session]
  ~name:"remove_from_roles"
  ~in_oss_since:None
  ~in_product_since:rel_midnight_ride
  ~params:[
    Ref _subject, "self", "The subject from whom we want to remove the role";
    Ref _role, "role", "The unique role reference in the subject's roles field" ; 
    ]
  ~doc:"This call removes a role from a subject"
  ()
let subject_get_permissions_name_label = call ~flags:[`Session]
  ~name:"get_permissions_name_label"
  ~in_oss_since:None
  ~in_product_since:rel_midnight_ride
  ~params:[
    Ref _subject, "self", "The subject whose permissions will be retrieved";
    ]
  ~result:(Set(String), "a list of permission names")
  ~doc:"This call returns a list of permission names given a subject"
  ()
(* a subject is a user/group that can log in xapi *)
let subject =
  create_obj ~in_db:true ~in_product_since:rel_george ~in_oss_since:None ~internal_deprecated_since:None ~persist:PersistEverything ~gen_constructor_destructor:false ~name:_subject ~descr:"A user or group that can log in xapi"
    ~gen_events:true
    ~doccomments:[]
    ~messages: [
      subject_create;(*customized create: new subjects must not have roles*)
      subject_destroy;
      subject_add_to_roles;
      subject_remove_from_roles;
      subject_get_permissions_name_label;
      ]
    ~contents:[uid ~in_oss_since:None _subject;
      field ~in_product_since:rel_george ~default_value:(Some (VString "")) ~qualifier:StaticRO ~ty:String "subject_identifier" "the subject identifier, unique in the external directory service";
      field ~in_product_since:rel_george ~default_value:(Some (VMap [])) ~qualifier:StaticRO ~ty:(Map(String, String)) "other_config" "additional configuration";
      field ~in_product_since:rel_midnight_ride ~default_value:(Some (VSet [])) ~ignore_foreign_key:true ~qualifier:StaticRO(*DynamicRO*) ~ty:(Set((Ref _role))) "roles" "the roles associated with this subject";
      ]
    ()

(** Role class *)
let role_get_permissions_name_label = call ~flags:[`Session]
  ~name:"get_permissions_name_label"
  ~in_oss_since:None
  ~in_product_since:rel_midnight_ride
  ~params:[
    Ref _role, "self", "the reference of a role";
    ]
  ~result:(Set(String), "a list of permission names")
  ~doc:"This call returns a list of permission names given a role"
  ()

let role_get_by_permission_name_label = call ~flags:[`Session]
  ~name:"get_by_permission_name_label"
  ~in_oss_since:None
  ~in_product_since:rel_midnight_ride
  ~params:[
    String, "label", "The short friendly name of the role" ;
    ]
  ~result:(Set(Ref _role), "a list of references to roles")
  ~doc:"This call returns a list of roles given a permission name"
  ()

(* A role defines a set of API call privileges associated with a subject *)
(* A role is synonymous to permission or privilege *)
(* A role is a recursive definition: it is either a basic role or it points to a set of roles *)
(* - full/complete role: is the one meant to be used by the end-user, a root in the tree of roles *)
(* - basic role: is the 1x1 mapping to each XAPI/HTTP call being protected, a leaf in the tree of roles *)
(* - intermediate role: an intermediate node in the recursive tree of roles, usually not meant to the end-user *)
let role =
  create_obj ~in_db:true ~in_product_since:rel_midnight_ride ~in_oss_since:None ~internal_deprecated_since:None ~persist:PersistEverything ~gen_constructor_destructor:true ~name:_role ~descr:"A set of permissions associated with a subject"
    ~gen_events:true
    ~force_custom_actions:true
    ~doccomments:[]
    ~messages: [
      (*RBAC2: get_permissions;*)
      role_get_permissions_name_label;
      (*RBAC2: get_by_permission;*)
      role_get_by_permission_name_label;
      ]
    ~contents: [uid ~in_oss_since:None _role;
      namespace ~name:"name" ~contents:(
        [
          field ~in_product_since:rel_midnight_ride ~default_value:(Some (VString "")) ~qualifier:StaticRO ~ty:String "label" "a short user-friendly name for the role";
          field ~in_product_since:rel_midnight_ride ~default_value:(Some (VString "")) ~qualifier:StaticRO ~ty:String "description" "what this role is for";
        ]);
      field ~in_product_since:rel_midnight_ride ~default_value:(Some (VSet [])) ~ignore_foreign_key:true ~qualifier:StaticRO ~ty:(Set(Ref _role)) "subroles" "a list of pointers to other roles or permissions";
      (*RBAC2: field ~in_product_since:rel_midnight_ride ~default_value:(Some (VBool false)) ~qualifier:StaticRO ~ty:Bool "is_complete" "if this is a complete role, meant to be used by the end-user";*)
      ]
    ()

(** A virtual disk interface *)
let vtpm =
    create_obj ~in_db:true ~in_product_since:rel_rio ~in_oss_since:oss_since_303 ~internal_deprecated_since:None ~persist:PersistEverything ~gen_constructor_destructor:true ~name:_vtpm ~descr:"A virtual TPM device"
      ~gen_events:false
      ~doccomments:[] 
      ~messages:[]
      ~contents:
      [ uid _vtpm;
	field ~qualifier:StaticRO ~ty:(Ref _vm) "VM" "the virtual machine"; 
	field ~qualifier:StaticRO ~ty:(Ref _vm) "backend" "the domain where the backend is located" ]
	()

(** Console protocols *)
let console_protocol = Enum("console_protocol", [
			      "vt100", "VT100 terminal";
			      "rfb", "Remote FrameBuffer protocol (as used in VNC)";
			      "rdp", "Remote Desktop Protocol"
			    ])

(** A virtual console device *)
let console = 
    create_obj ~in_db:true ~in_product_since:rel_rio ~in_oss_since:oss_since_303 ~internal_deprecated_since:None ~persist:PersistEverything ~gen_constructor_destructor:true ~name:_console ~descr:"A console"
      ~gen_events:true
      ~doccomments:[] 
      ~messages:[]  ~contents:
      [ uid _console;
	field ~qualifier:DynamicRO ~ty:console_protocol "protocol" "the protocol used by this console";
	field ~qualifier:DynamicRO ~ty:String "location" "URI for the console service";
	field ~qualifier:DynamicRO ~ty:(Ref _vm) "VM" "VM to which this console is attached";
	field  ~ty:(Map(String, String)) "other_config" "additional configuration";
	field ~in_oss_since:None ~internal_only:true ~ty:Int "port" "port in dom0 on which the console server is listening";
      ]
	()

(* PV domain booting *)
let pv =
  [
    field "bootloader" "name of or path to bootloader";
    field "kernel" "path to the kernel";
    field "ramdisk" "path to the initrd";
    field "args" "kernel command-line arguments";
    field "bootloader_args" "miscellaneous arguments for the bootloader";
    field ~in_oss_since:None "legacy_args" "to make Zurich guests boot";
  ]

(** HVM domain booting *)
let hvm =
  [
    field "boot_policy" "HVM boot policy";
    field ~ty:(Map(String, String)) "boot_params" "HVM boot params";
    field ~in_oss_since:None ~ty:Float ~in_product_since:rel_miami ~qualifier:StaticRO "shadow_multiplier" "multiplier applied to the amount of shadow that will be made available to the guest" ~default_value:(Some (VFloat 1.))
  ]

(** Action to take on guest reboot/power off/sleep etc *)
(*
let power_behaviour =
  Enum ("power_behaviour", [ "destroy", "destroy the VM state"; 
			     "restart", "automatically restart the VM"; 
			     "preserve", "leave VM running"; 
			     "rename_restart", "leave VM running and restart a new one" ])
*)
let on_crash_behaviour = 
  Enum ("on_crash_behaviour", [ "destroy", "destroy the VM state";
				"coredump_and_destroy", "record a coredump and then destroy the VM state";
				"restart", "restart the VM";
				"coredump_and_restart", "record a coredump and then restart the VM";
				"preserve", "leave the crashed VM paused";
				"rename_restart", "rename the crashed VM and start a new copy" ])

let on_normal_exit_behaviour = 
  Enum ("on_normal_exit", [ "destroy", "destroy the VM state";
			    "restart", "restart the VM" ])


(** Virtual CPUs *)
let vcpus =
  [
    field ~ty:(Map(String, String)) "params" "configuration parameters for the selected VCPU policy";
    field ~qualifier:StaticRO ~ty:Int "max" "Max number of VCPUs";
    field ~qualifier:StaticRO ~ty:Int "at_startup" "Boot number of VCPUs";
  ]

(** Default actions *)
let actions =
  let crash = field ~effect:true ~ty:on_crash_behaviour in
  let normal = field ~effect:true ~ty:on_normal_exit_behaviour in
  [
    normal "after_shutdown" "action to take after the guest has shutdown itself";
    normal "after_reboot" "action to take after the guest has rebooted itself";
    crash "after_crash" "action to take if the guest crashes";
  ]

let vm_power_state =
  Enum ("vm_power_state", [ "Halted", "VM is offline and not using any resources";
			    "Paused", "All resources have been allocated but the VM itself is paused and its vCPUs are not running";
			    "Running", "Running";
			    "Suspended", "VM state has been saved to disk and it is nolonger running. Note that disks remain in-use while the VM is suspended.";
			    "Unknown", "Some other unknown state"])

let vm_operations = 
  Enum ("vm_operations",
	List.map operation_enum
	  [ vm_snapshot; vm_clone; vm_copy; vm_create_template; vm_revert; vm_checkpoint; vm_snapshot_with_quiesce;
		vm_provision; vm_start; vm_start_on; vm_pause; vm_unpause; vm_cleanShutdown;
	    vm_cleanReboot; vm_hardShutdown; vm_stateReset; vm_hardReboot;
	    vm_suspend; csvm; vm_resume; vm_resume_on;
	    vm_pool_migrate;
            vm_migrate; 
	    vm_get_boot_record; vm_send_sysrq; vm_send_trigger ]
	@ [ "changing_memory_live", "Changing the memory settings";
	    "awaiting_memory_live", "Waiting for the memory settings to change";
	    "changing_dynamic_range", "Changing the memory dynamic range";
	    "changing_static_range", "Changing the memory static range";
	    "changing_memory_limits", "Changing the memory limits";
	    "get_cooperative", "Querying the co-operativeness of the VM";
	    "changing_shadow_memory", "Changing the shadow memory for a halted VM.";
	    "changing_shadow_memory_live", "Changing the shadow memory for a running VM.";
	    "changing_VCPUs", "Changing VCPU settings for a halted VM.";
	    "changing_VCPUs_live", "Changing VCPU settings for a running VM.";
	    "assert_operation_valid", "";
	    "data_source_op", "Add, remove, query or list data sources";
	    "update_allowed_operations", "";
	    "make_into_template", "Turning this VM into a template";
	    "import", "importing a VM from a network stream";
	    "export", "exporting a VM to a network stream";
	    "metadata_export", "exporting VM metadata to a network stream";
	    "reverting", "Reverting the VM to a previous snapshotted state";
	    "destroy", "refers to the act of uninstalling the VM"; ]
       )

(** VM (or 'guest') configuration: *)
let vm =
    create_obj ~in_db:true ~in_product_since:rel_rio ~in_oss_since:oss_since_303 ~internal_deprecated_since:None ~persist:PersistEverything ~gen_constructor_destructor:true ~name:_vm ~descr:"A virtual machine (or 'guest')."
      ~gen_events:true
      ~doccomments:[ "destroy", "Destroy the specified VM.  The VM is completely removed from the system.  This function can only be called when the VM is in the Halted State." ]
      ~messages:[ vm_snapshot; vm_snapshot_with_quiesce; vm_clone; vm_copy; vm_create_template; vm_revert; vm_checkpoint;
		vm_provision; vm_start; vm_start_on; vm_pause; vm_unpause; vm_cleanShutdown;
		vm_cleanReboot; vm_hardShutdown; vm_stateReset; vm_hardReboot; vm_suspend; csvm; vm_resume; 
		vm_hardReboot_internal;
		vm_resume_on; 
		vm_pool_migrate; set_vcpus_number_live;
		vm_add_to_VCPUs_params_live;
		vm_set_ha_restart_priority;  (* updates the allowed-operations of the VM *)
		vm_set_ha_always_run;        (* updates the allowed-operations of the VM *)
		vm_compute_memory_overhead;
		vm_set_memory_dynamic_max;
		vm_set_memory_dynamic_min;
		vm_set_memory_dynamic_range;
		vm_set_memory_static_max;
		vm_set_memory_static_min;
		vm_set_memory_static_range;
		vm_set_memory_limits;
		vm_set_memory_target_live;
		vm_wait_memory_target_live;
		vm_get_cooperative;
		vm_set_HVM_shadow_multiplier;
		vm_set_shadow_multiplier_live;
		vm_set_VCPUs_max;
		vm_set_VCPUs_at_startup;
		vm_send_sysrq; vm_send_trigger;
		vm_maximise_memory;
		vm_migrate;
		vm_get_boot_record;
		vm_get_data_sources; vm_record_data_source; vm_query_data_source; vm_forget_data_source_archives;
		assert_operation_valid vm_operations _vm _self;
		update_allowed_operations vm_operations _vm _self;
		vm_get_allowed_VBD_devices;
		vm_get_allowed_VIF_devices;
		vm_get_possible_hosts;
		vm_assert_can_boot_here;
		vm_atomic_set_resident_on;
		vm_create_new_blob;
		vm_assert_agile;
		vm_update_snapshot_metadata;
		vm_retrieve_wlb_recommendations;
		]
      ~contents:
      ([ uid _vm;
      ] @ (allowed_and_current_operations vm_operations) @ [
	field ~qualifier:DynamicRO ~ty:vm_power_state "power_state" "Current power state of the machine";
	namespace ~name:"name" ~contents:(names oss_since_303 RW);

	field ~ty:Int "user_version" "a user version number for this machine";
	field ~effect:true ~ty:Bool "is_a_template" "true if this is a template. Template VMs can never be started, they are used only for cloning other VMs";
	field ~qualifier:DynamicRO ~ty:(Ref _vdi) "suspend_VDI" "The VDI that a suspend image is stored on. (Only has meaning if VM is currently suspended)";

	field ~qualifier:DynamicRO ~ty:(Ref _host) "resident_on" "the host the VM is currently resident on";
	field ~in_oss_since:None ~internal_only:true ~qualifier:DynamicRO ~ty:(Ref _host) "scheduled_to_be_resident_on" "the host on which the VM is due to be started/resumed/migrated. This acts as a memory reservation indicator";
	field ~in_oss_since:None ~ty:(Ref _host) "affinity" "a host which the VM has some affinity for (or NULL). This is used as a hint to the start call when it decides where to run the VM. Implementations are free to ignore this field.";

	namespace ~name:"memory" ~contents:guest_memory;
	namespace ~name:"VCPUs" ~contents:vcpus;
	namespace ~name:"actions" ~contents:actions;
	
	field ~qualifier:DynamicRO ~ty:(Set (Ref _console)) "consoles" "virtual console devices";
	field ~qualifier:DynamicRO ~ty:(Set (Ref _vif)) "VIFs" "virtual network interfaces";
	field ~qualifier:DynamicRO ~ty:(Set (Ref _vbd)) "VBDs" "virtual block devices";
	field ~qualifier:DynamicRO ~ty:(Set (Ref _crashdump)) "crash_dumps" "crash dumps associated with this VM";
	field ~qualifier:DynamicRO ~ty:(Set (Ref _vtpm)) "VTPMs" "virtual TPMs";
	
	namespace ~name:"PV" ~contents:pv;
	namespace ~name:"HVM" ~contents:hvm;
	field  ~ty:(Map(String, String)) "platform" "platform-specific configuration";

	field "PCI_bus" "PCI bus path for pass-through devices";
	field  ~ty:(Map(String, String)) "other_config" "additional configuration";
	field ~qualifier:DynamicRO ~ty:Int "domid" "domain ID (if available, -1 otherwise)";
	field ~qualifier:DynamicRO ~in_oss_since:None ~ty:String "domarch" "Domain architecture (if available, null string otherwise)";
	field ~in_oss_since:None ~qualifier:DynamicRO ~ty:(Map(String, String)) "last_boot_CPU_flags" "describes the CPU flags on which the VM was last booted";
	field ~qualifier:DynamicRO ~ty:Bool "is_control_domain" "true if this is a control domain (domain 0 or a driver domain)";
	field ~qualifier:DynamicRO ~ty:(Ref _vm_metrics) "metrics" "metrics associated with this VM";
	field ~qualifier:DynamicRO ~ty:(Ref _vm_guest_metrics) "guest_metrics" "metrics associated with the running guest";
	(* This was an internal field in Rio, Miami beta1, Miami beta2 but is now exposed so that
	   it will be included automatically in Miami GA exports and can be restored, important if
	   the VM is in a suspended state *)
	field ~in_oss_since:None ~internal_only:false ~in_product_since:rel_miami ~qualifier:DynamicRO ~ty:String "last_booted_record" "marshalled value containing VM record at time of last boot, updated dynamically to reflect the runtime state of the domain" ~default_value:(Some (VString ""));
	field ~in_oss_since:None ~ty:String "recommendations" "An XML specification of recommended values and ranges for properties of this VM";
	field ~in_oss_since:None ~ty:(Map(String, String)) ~in_product_since:rel_miami ~qualifier:RW "xenstore_data" "data to be inserted into the xenstore tree (/local/domain/<domid>/vm-data) after the VM is created." ~default_value:(Some (VMap []));
	field ~in_oss_since:None ~ty:Bool ~in_product_since:rel_orlando ~qualifier:StaticRO "ha_always_run" "if true then the system will attempt to keep the VM running as much as possible." ~default_value:(Some (VBool false));
	field ~in_oss_since:None ~ty:String ~in_product_since:rel_orlando ~qualifier:StaticRO "ha_restart_priority" "Only defined if ha_always_run is set possible values: \"best-effort\" meaning \"try to restart this VM if possible but don't consider the Pool to be overcommitted if this is not possible\"; and a numerical restart priority (e.g. 1, 2, 3,...)" ~default_value:(Some (VString ""));
	field ~qualifier:DynamicRO ~in_product_since:rel_orlando ~default_value:(Some (VBool false))          ~ty:Bool            "is_a_snapshot" "true if this is a snapshot. Snapshotted VMs can never be started, they are used only for cloning other VMs";
	field ~qualifier:DynamicRO ~in_product_since:rel_orlando ~default_value:(Some (VRef ""))              ~ty:(Ref _vm)       "snapshot_of" "Ref pointing to the VM this snapshot is of.";
	field ~qualifier:DynamicRO ~in_product_since:rel_orlando                                              ~ty:(Set (Ref _vm)) "snapshots" "List pointing to all the VM snapshots.";
	field ~qualifier:DynamicRO ~in_product_since:rel_orlando ~default_value:(Some (VDateTime Date.never)) ~ty:DateTime        "snapshot_time" "Date/time when this snapshot was created.";
	field ~qualifier:DynamicRO ~in_product_since:rel_orlando ~default_value:(Some (VString ""))           ~ty:String          "transportable_snapshot_id" "Transportable ID of the snapshot VM";
	field ~qualifier:DynamicRO ~in_product_since:rel_orlando ~ty:(Map(String, Ref _blob)) ~default_value:(Some (VMap [])) "blobs" "Binary blobs associated with this VM";
	field  ~in_product_since:rel_orlando ~default_value:(Some (VSet [])) ~ty:(Set String) "tags" "user-specified tags for categorization purposes";
	field ~in_product_since:rel_orlando ~default_value:(Some (VMap [])) ~qualifier:RW ~ty:(Map(vm_operations, String)) "blocked_operations" "List of operations which have been explicitly blocked and an error code";
	
	field ~qualifier:DynamicRO ~in_product_since:rel_midnight_ride ~default_value:(Some (VMap []))    ~ty:(Map (String, String)) "snapshot_info"     "Human-readable information concerning this snapshot";
	field ~qualifier:DynamicRO ~in_product_since:rel_midnight_ride ~default_value:(Some (VString "")) ~ty:String                 "snapshot_metadata" "Encoded information about the VM's metadata this is a snapshot of";

	field ~qualifier:DynamicRO ~in_product_since:rel_midnight_ride ~default_value:(Some (VRef "")) ~ty:(Ref _vm)       "parent"       "Ref pointing to the parent of this VM";
	field ~qualifier:DynamicRO ~in_product_since:rel_midnight_ride                                 ~ty:(Set (Ref _vm)) "children"     "List pointing to all the children of this VM";

      ])
	()

let vm_memory_metrics = 
  [
    field ~qualifier:DynamicRO ~ty:Int "actual" "Guest's actual memory (bytes)" ~persist:false
  ]

let vm_vcpu_metrics =
  [
    field ~qualifier:DynamicRO ~ty:Int "number" "Current number of VCPUs" ~persist:true;
    field ~qualifier:DynamicRO ~ty:(Map (Int, Float)) "utilisation" "Utilisation for all of guest's current VCPUs" ~persist:false;
    field ~qualifier:DynamicRO ~ty:(Map (Int, Int)) "CPU" "VCPU to PCPU map" ~persist:false;
    field ~qualifier:DynamicRO ~ty:(Map (String, String)) "params" "The live equivalent to VM.VCPUs_params" ~persist:false;
    field ~qualifier:DynamicRO ~ty:(Map (Int, Set String)) "flags" "CPU flags (blocked,online,running)" ~persist:false;
  ]

let vm_metrics = 
    create_obj ~in_db:true ~in_product_since:rel_rio ~in_oss_since:oss_since_303 ~internal_deprecated_since:None ~persist:PersistEverything ~gen_constructor_destructor:false ~name:_vm_metrics ~descr:"The metrics associated with a VM"
      ~gen_events:true
      ~doccomments:[]
      ~messages:[] ~contents:
      [ uid _vm_metrics;
	namespace ~name:"memory" ~contents:vm_memory_metrics;
	namespace ~name:"VCPUs" ~contents:vm_vcpu_metrics;
	field ~qualifier:DynamicRO ~ty:(Set (String)) "state" "The state of the guest, eg blocked, dying etc" ~persist:false;
	field ~qualifier:DynamicRO ~ty:DateTime "start_time" "Time at which this VM was last booted";
	field ~in_oss_since:None ~qualifier:DynamicRO ~ty:DateTime "install_time" "Time at which the VM was installed";
	field ~qualifier:DynamicRO ~ty:DateTime "last_updated" "Time at which this information was last updated" ~persist:false;
	field ~in_product_since:rel_orlando ~default_value:(Some (VMap [])) ~ty:(Map(String, String)) "other_config" "additional configuration" ~persist:false;
      ]
	()

(* Some of this stuff needs to persist (like PV drivers vsns etc.) so we know about what's likely to be in the VM even when it's off.
   Other things don't need to persist, so we specify these on a per-field basis *)
let vm_guest_metrics =
  create_obj ~in_db:true ~in_product_since:rel_rio ~in_oss_since:oss_since_303 ~internal_deprecated_since:None ~persist:PersistEverything ~gen_constructor_destructor:false ~name:_vm_guest_metrics ~descr:"The metrics reported by the guest (as opposed to inferred from outside)"
    ~gen_events:true
    ~doccomments:[]
    ~messages:[] ~contents:
    [ uid _vm_guest_metrics;
      field ~qualifier:DynamicRO ~ty:(Map(String, String)) "os_version" "version of the OS";
      field ~qualifier:DynamicRO ~ty:(Map(String, String)) "PV_drivers_version" 
	"version of the PV drivers";
      field ~qualifier:DynamicRO ~ty:Bool ~in_oss_since:None "PV_drivers_up_to_date"
	"true if the PV drivers appear to be up to date";

      field ~persist:false ~qualifier:DynamicRO ~ty:(Map(String, String)) "memory" "free/used/total memory";
      field ~persist:false ~qualifier:DynamicRO ~ty:(Map(String, String)) "disks" "disk configuration/free space";
      field ~persist:false ~qualifier:DynamicRO ~ty:(Map(String, String)) "networks" "network configuration";
      field ~persist:false  ~qualifier:DynamicRO ~ty:(Map(String, String)) "other" "anything else";
      field ~persist:false ~qualifier:DynamicRO ~ty:DateTime "last_updated" "Time at which this information was last updated";
      field ~in_product_since:rel_orlando ~default_value:(Some (VMap [])) ~ty:(Map(String, String)) "other_config" "additional configuration";
      field ~qualifier:DynamicRO ~in_product_since:rel_orlando ~default_value:(Some (VBool false)) ~ty:Bool "live" "True if the guest is sending heartbeat messages via the guest agent";
    ]
    ()

(** events handling: *)

let event_operation = Enum ("event_operation",
			    [ "add", "An object has been created";
			      "del", "An object has been deleted";
                              "mod", "An object has been modified"])
let event =
  let register = call
    ~name:"register" 
    ~in_product_since:rel_rio
    ~params:[Set String, "classes", "register for events for the indicated classes"]
    ~doc:"Registers this session with the event system.  Specifying the empty list will register for all classes."
    () in
  let unregister = call
    ~name:"unregister"
    ~in_product_since:rel_rio
    ~params:[Set String, "classes", "remove this session's registration for the indicated classes"]
    ~doc:"Unregisters this session with the event system"
    () in
  let next = call
    ~name:"next" ~params:[]
    ~in_product_since:rel_rio
    ~doc:"Blocking call which returns a (possibly empty) batch of events"
    ~custom_marshaller:true
    ~flags:[`Session]
    ~result:(Set (Record _event), "the batch of events")
    ~errs:[Api_errors.session_not_registered;Api_errors.events_lost]
      () in
  let get_current_id = call
    ~name:"get_current_id" ~params:[]
    ~in_product_since:rel_rio
    ~doc:"Return the ID of the next event to be generated by the system"
    ~flags:[`Session]
    ~result:(Int, "the event ID")
    () in
  (* !!! This should call create_obj ~in_db:true like everything else... !!! *)
  {
    name = _event;
    gen_events = false;
    description = "Asynchronous event registration and handling";
    gen_constructor_destructor = false;
    doccomments = [];
    messages = [ register; unregister; next; get_current_id ];
    obj_release = {internal=get_product_releases rel_rio; opensource=get_oss_releases (Some "3.0.3"); internal_deprecated_since=None};
    contents = [
      field ~qualifier:StaticRO ~ty:Int "id" "An ID, monotonically increasing, and local to the current session";
      field ~qualifier:StaticRO ~ty:DateTime "timestamp" "The time at which the event occurred";
      field ~qualifier:StaticRO ~ty:String "class" "The name of the class of the object that changed";
      field ~qualifier:StaticRO ~ty:event_operation "operation" "The operation that was performed";
      field ~qualifier:StaticRO ~ty:String "ref" "A reference to the object that changed";
      field ~qualifier:StaticRO ~ty:String "obj_uuid" "The uuid of the object that changed";
    ];
    persist = PersistNothing;
    in_database=false;
    force_custom_actions=false;
  }

(** Blobs - binary blobs of data *)

let blob = 
  let create = call
    ~name:"create"
    ~in_product_since:rel_orlando
    ~params:[String, "mime_type", "The mime-type of the blob. Defaults to 'application/octet-stream' if the empty string is supplied"]
    ~doc:"Create a placeholder for a binary blob"
    ~flags:[`Session]
    ~result:(Ref _blob, "The reference to the created blob")
    () in
  let destroy = call
    ~name:"destroy"
    ~in_product_since:rel_orlando
    ~params:[Ref _blob, "self", "The reference of the blob to destroy"]
    ~flags:[`Session]
    () in
  create_obj ~in_db:true ~in_product_since:rel_orlando ~in_oss_since:None ~internal_deprecated_since:None ~persist:PersistEverything ~gen_constructor_destructor:false ~name:_blob ~descr:"A placeholder for a binary blob"
    ~gen_events:true
    ~doccomments:[]
    ~messages:[create;destroy] ~contents:
    [ uid _blob;
      namespace ~name:"name" ~contents:(names oss_since_303 RW);
      field ~qualifier:DynamicRO ~ty:Int "size" "Size of the binary data, in bytes";
      field ~qualifier:StaticRO ~ty:DateTime "last_updated" "Time at which the data in the blob was last updated";
      field ~qualifier:StaticRO ~ty:String "mime_type" "The mime type associated with this object. Defaults to 'application/octet-stream' if the empty string is supplied"]
    ()

let message =
  let cls =
    Enum ("cls", [ "VM", "VM";
                   "Host", "Host";
		   "SR", "SR";
		   "Pool","Pool";])
  in
  let create = call
    ~name:"create"
    ~in_product_since:rel_orlando
    ~params:[String, "name", "The name of the message";
	     Int, "priority", "The priority of the message";
	     cls, "cls", "The class of object this message is associated with";
	     String, "obj_uuid", "The uuid of the object this message is associated with";
	     String, "body", "The body of the message"]
    ~flags:[`Session]
    ~result:(Ref _message, "The reference of the created message")
    ()
  in
  let destroy = call
    ~name:"destroy"
    ~in_product_since:rel_orlando
    ~params:[Ref _message, "self", "The reference of the message to destroy"]
    ~flags:[`Session]
    ()
  in
  let get_all = call 
    ~name:"get_all"
    ~in_product_since:rel_orlando
    ~params:[]
    ~flags:[`Session]
    ~result:(Set(Ref _message), "The references to the messages")
    ()
  in
  let get = call
    ~name:"get"
    ~in_product_since:rel_orlando
    ~params:[cls, "cls", "The class of object";
	     String, "obj_uuid", "The uuid of the object";
	     DateTime, "since", "The cutoff time"]
    ~flags:[`Session]
    ~result:(Map(Ref _message, Record _message), "The relevant messages")
    ()
  in
  let get_since = call
    ~name:"get_since"
    ~in_product_since:rel_orlando
    ~params:[DateTime, "since", "The cutoff time"]
    ~flags:[`Session]
    ~result:(Map(Ref _message, Record _message), "The relevant messages")
    ()
  in
  let get_by_uuid = call
    ~name:"get_by_uuid"
    ~in_product_since:rel_orlando
    ~params:[String, "uuid", "The uuid of the message"]
    ~flags:[`Session]
    ~result:(Ref _message, "The message reference")
    ()
  in
  let get_record = call
    ~name:"get_record"
    ~in_product_since:rel_orlando
    ~params:[Ref _message, "self", "The reference to the message"]
    ~flags:[`Session]
    ~result:(Record _message, "The message record")
    ()
  in
  let get_all_records = call 
    ~name:"get_all_records"
    ~in_product_since:rel_orlando
    ~params:[]
    ~flags:[`Session]
    ~result:(Map(Ref _message, Record _message), "The messages")
    ()
  in
  let get_all_records_where = call 
    ~name:"get_all_records_where"
    ~in_product_since:rel_orlando
    ~params:[String, "expr", "The expression to match (not currently used)"]
    ~flags:[`Session]
    ~result:(Map(Ref _message, Record _message), "The messages")
    ()
  in
  create_obj ~in_db:false ~in_product_since:rel_orlando ~in_oss_since:None ~persist:PersistNothing ~gen_constructor_destructor:false ~name:_message ~descr:"An message for the attention of the administrator" ~gen_events:true
    ~doccomments:[] ~internal_deprecated_since:None
    ~messages:[create;destroy;get;get_all; get_since; get_record; get_by_uuid; get_all_records; get_all_records_where] ~contents:
    [ uid _message;
      field ~qualifier:DynamicRO ~ty:String "name" "The name of the message";
      field ~qualifier:DynamicRO ~ty:Int "priority" "The message priority, 0 being low priority";
      field ~qualifier:DynamicRO ~ty:cls "cls" "The class of the object this message is associated with";
      field ~qualifier:DynamicRO ~ty:String "obj_uuid" "The uuid of the object this message is associated with";
      field ~qualifier:DynamicRO ~ty:DateTime "timestamp" "The time at which the message was created";
      field ~qualifier:DynamicRO ~ty:String "body" "The body of the message"; ]
    ()
    

(*

let alert =
  create_obj ~in_product_since:rel_miami ~in_oss_since:None ~internal_deprecated_since:None ~persist:PersistEverything ~gen_constructor_destructor:true ~name:_alert ~descr:"Notification information"
    ~gen_events:true
    ~doccomments:[]
    ~messages: []
    ~contents:
    [
     uid ~in_oss_since:None _alert;
     field ~in_oss_since:None ~qualifier:StaticRO ~ty:String "message" "description of the alert";
     field ~in_oss_since:None ~qualifier:StaticRO ~ty:(Map (String, String)) ~default_value:(Some (VMap [])) "params" "parameters of the alert";
     field ~in_oss_since:None ~qualifier:StaticRO ~ty:alert_level "level" "level of importance (info/warning/error/critical)";
     field ~in_oss_since:None ~qualifier:DynamicRO ~ty:Bool "system" "system task";
     field ~in_oss_since:None ~qualifier:DynamicRO ~ty:(Ref _task) "task" "task related to this alert (null reference if there's no task associated)";
    ]
    ()
*)

(******************************************************************************************)

(** All the objects in the system in order they will appear in documentation: *)
let all_system =
  [
    session;
    auth;
    subject;
    (role:Datamodel_types.obj);
    task;
    event;
    (* alert; *)

    pool;
    pool_patch;

    vm;
    vm_metrics;
    vm_guest_metrics;
    host;
    host_crashdump;
    host_patch;
    host_metrics;
    hostcpu;
    (* network_manager; *)
    network;
    vif;
    vif_metrics;
    pif;
    pif_metrics;
    bond;
    vlan;
    storage_plugin;
    storage_repository;
    vdi;
    vbd;
    vbd_metrics;
    pbd;
    crashdump;
    (* misc *)
    vtpm;
    console;
    (* filesystem; *)
    user; 
    data_source;
    blob;
    message;
  ]

(** These are the pairs of (object, field) which are bound together in the database schema *)
(* If the relation is one-to-many, the "many" nodes (one edge each) must come before the "one" node (many edges) *)
let all_relations =
  [
    (* snapshots *)
    (_vm, "snapshot_of"), (_vm, "snapshots");
    (_vdi, "snapshot_of"), (_vdi, "snapshots");
    (_vm, "parent"), (_vm, "children");

    (* subtasks hierarchy *)
    (_task, "subtask_of"), (_task, "subtasks");
    
    (_pif, "bond_slave_of"), (_bond, "slaves");
    (_bond, "master"), (_pif, "bond_master_of");
    (_vlan, "tagged_PIF"), (_pif, "VLAN_slave_of");

    (_pbd, "host"), (_host, "PBDs");
    (_pbd, "SR"), (_sr, "PBDs");

    (_vbd, "VDI"), (_vdi, "VBDs"); 
    (_crashdump, "VDI"), (_vdi, "crash_dumps");
(*  (_vdi, "parent"), (_vdi, "children"); *)

    (_vbd, "VM"), (_vm, "VBDs");
    (_crashdump, "VM"), (_vm, "crash_dumps");

    (* VM <-> VIF <-> network *)
    (_vif, "VM"), (_vm, "VIFs");
    (_vif, "network"), (_network, "VIFs");

    (* host <-> PIF <-> network *)
    (_pif, "host"), (_host, "PIFs");
    (_pif, "network"), (_network, "PIFs");

    (_vdi, "SR"), (_sr, "VDIs");

(*  (_alert, "task"), (_task, "alerts"); *)

    (_vtpm, "VM"), (_vm, "VTPMs");
    (_console, "VM"), (_vm, "consoles");

    (_vm, "resident_on"), (_host, "resident_VMs");
    (_hostcpu, "host"), (_host, "host_CPUs");

    (_host_crashdump, "host"), (_host, "crashdumps");
    (_host_patch, "host"), (_host, "patches");
    (_host_patch, "pool_patch"), (_pool_patch, "host_patches");

    (_subject, "roles"), (_subject, "roles");
    (*(_subject, "roles"), (_role, "subjects");*)
    (_role, "subroles"), (_role, "subroles");
  ]

(** the full api specified here *)
let all_api = Dm_api.make (all_system, all_relations)

(** These are the "emergency" calls that can be performed when a host is in "emergency mode" *)
let emergency_calls =
  [ (pool,pool_slave_reset_master);
    (pool,pool_transition_to_master); 
    (pool,pool_ping_slave);
    (session,slave_local_login);
    (session,slave_local_login_with_password);
    (session,local_logout);
    (host,host_propose_new_master);
    (host,host_commit_new_master);
    (host,host_abort_new_master);
    (host,host_local_assert_healthy);
    (host,host_signal_networking_change);
    (host,host_local_management_reconfigure);
    (host,host_ha_xapi_healthcheck);
    (host,host_emergency_ha_disable);
    (host,host_management_disable);
    (host,host_get_system_status_capabilities);
    (host,host_is_in_emergency_mode);
    (host,host_shutdown_agent);
  ]

(** Whitelist of calls that will not get forwarded from the slave to master via the unix domain socket *)
let whitelist = [ (session,session_login); 
		  (session,slave_login); 
		] @ emergency_calls

(* perform consistency checks on api at initialisation time *)
let _ = Dm_api.check all_api (List.map (fun (obj,msg) -> obj.name, msg.msg_name) emergency_calls)

(** List of classes to skip generating async handlers for *)
let no_async_messages_for = [ _session; _event; (* _alert; *) _task; _data_source; _blob ]

(** List of classes to generate 'get_all' messages for (currently we don't allow
    a user to enumerate all the VBDs or VDIs directly: that must be through a VM
    or SR *)
let expose_get_all_messages_for = [ _task; (* _alert; *) _host; _host_metrics; _hostcpu; _sr; _vm; _vm_metrics; _vm_guest_metrics;
				    _network; _vif; _vif_metrics; _pif; _pif_metrics; _pbd; _vdi; _vbd; _vbd_metrics; _console; 
				    _crashdump; _host_crashdump; _host_patch; _pool; _sm; _pool_patch; _bond; _vlan; _blob; _subject; _role ]


let no_task_id_for = [ _task; (* _alert; *) _event ]

let current_operations_for = [ _vm; (* _vdi; _host; _sr *) ]

(*** HTTP actions ***)

type action_arg =   (* I'm not using Datamodel_types here because we need varargs *)
   String_query_arg of string |
   Int64_query_arg of string |
   Bool_query_arg of string |
   Varargs_query_arg

type http_meth = Get | Put | Post | Connect

(* Each action has:
   (unique public name, (HTTP method, URI, whether to expose in SDK, [args to expose in SDK]))
*)

let http_actions = [
  ("post_remote_db_access", (Post, Constants.remote_db_access_uri, false, []));
  ("connect_migrate", (Connect, Constants.migrate_uri, false, []));
  ("put_import", (Put, Constants.import_uri, true,
		  [Bool_query_arg "restore"; Bool_query_arg "force"; String_query_arg "sr_id"]));
  ("put_import_metadata", (Put, Constants.import_metadata_uri, true,
			   [Bool_query_arg "restore"; Bool_query_arg "force"]));
  ("put_import_raw_vdi", (Put, Constants.import_raw_vdi_uri, true, [String_query_arg "vdi"]));
  ("get_export", (Get, Constants.export_uri, true, [String_query_arg "uuid"]));
  ("get_export_metadata", (Get, Constants.export_metadata_uri, true, [String_query_arg "uuid"]));
  ("connect_console", (Connect, Constants.console_uri, false, []));
  ("get_root", (Get, "/", false, []));
  ("post_cli", (Post, Constants.cli_uri, false, []));
  ("get_host_backup", (Get, Constants.host_backup_uri, true, []));
  ("put_host_restore", (Put, Constants.host_restore_uri, true, []));
  ("get_host_logs_download", (Get, Constants.host_logs_download_uri, true, []));
  ("put_pool_patch_upload", (Put, Constants.pool_patch_upload_uri, true, []));
  ("get_pool_patch_download", (Get, Constants.pool_patch_download_uri, true, [String_query_arg "uuid"]));
  ("put_oem_patch_stream", (Put, Constants.oem_patch_stream_uri, true, []));
  ("get_vncsnapshot", (Get, Constants.vncsnapshot_uri, true, [String_query_arg "uuid"]));
  ("get_pool_xml_db_sync", (Get, Constants.pool_xml_db_sync, true, []));
  ("put_pool_xml_db_sync", (Put, Constants.pool_xml_db_sync, false, []));
  ("get_config_sync", (Get, Constants.config_sync_uri, false, []));
  ("get_vm_connect", (Get, Constants.vm_connect_uri, false, []));
  ("put_vm_connect", (Put, Constants.vm_connect_uri, false, []));
  ("get_system_status", (Get, Constants.system_status_uri, true,
			 [String_query_arg "entries"; String_query_arg "output"]));
  ("get_vm_rrd", (Get, Constants.vm_rrd_uri, true, [String_query_arg "uuid"]));
  ("put_rrd", (Put, Constants.rrd_put_uri, false, []));
  ("get_host_rrd", (Get, Constants.host_rrd_uri, true, [Bool_query_arg "json"]));
  ("get_rrd_updates", (Get, Constants.rrd_updates, true,
		       [Int64_query_arg "start"; String_query_arg "cf"; Int64_query_arg "interval";
			Bool_query_arg "host"; String_query_arg "uuid"; Bool_query_arg "json"]));
  ("get_blob", (Get, Constants.blob_uri, true, [String_query_arg "ref"]));
  ("put_blob", (Put, Constants.blob_uri, true, [String_query_arg "ref"]));
  ("get_message_rss_feed", (Get, Constants.message_rss_feed, false, []));  (* not enabled in xapi *)
  ("connect_remotecmd", (Connect, Constants.remotecmd_uri, false, []));
  ("post_remote_stats", (Post, Constants.remote_stats_uri, false, []));  (* deprecated *)
  ("get_wlb_report", (Get, Constants.wlb_report_uri, true,
		      [String_query_arg "report"; Varargs_query_arg]));
  ("get_wlb_diagnostics", (Get, Constants.wlb_diagnostics_uri, true, []));

  (* XMLRPC callback *)
  ("post_root", (Post, "/", false, []));
  (* JSON callback *)
  ("post_json", (Post, Constants.json_uri, false, []));
]

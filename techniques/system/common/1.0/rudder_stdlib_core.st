#####################################################################################
# Copyright 2012-2014 Normation SAS
#####################################################################################
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, Version 3.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#####################################################################################
#
# Rudder Promise Body and Bundle Library - core part
#
# This library includes standardized bundles and bodies to be used as part of the
# "best practices" in the Techniques writing, for classes and reporting only.
# Other bodies and bundles should be included in rudder_stdlib.st
#

##################################################
# classes bodies
##################################################

#
# Automatically defines classes bases on a given prefix
# The classes are defined based on the romises outcome
#
body classes rudder_common_classes(prefix)
{
        promise_kept     => { "${prefix}_kept"    , "${prefix}_ok" };
        promise_repaired => { "${prefix}_repaired", "${prefix}_ok" };
        repair_failed    => { "${prefix}_failed"  , "${prefix}_error" };
        repair_denied    => { "${prefix}_denied"  , "${prefix}_error" };
        repair_timeout   => { "${prefix}_timeout" , "${prefix}_error" };
}

#
# Automatically defines classes bases on a given prefix
# The classes are defined based on the promises outcome
# Same as above but persist classes for ${persist} mins
#
body classes rudder_common_classes_persist(prefix, persist)
{
        promise_kept     => { "${prefix}_kept"    , "${prefix}_ok" };
        promise_repaired => { "${prefix}_repaired", "${prefix}_ok" };
        repair_failed    => { "${prefix}_failed"  , "${prefix}_error" };
        repair_denied    => { "${prefix}_denied"  , "${prefix}_error" };
        repair_timeout   => { "${prefix}_timeout" , "${prefix}_error" };

        persist_time     => ${persist};
}

#
# Always define a class, with the given persist time
# Define the class for ${persist} minutes
#
body classes rudder_always_classes_persist(always, persist)
{
  promise_kept     => { "${always}" };
  promise_repaired => { "${always}" };
  repair_failed    => { "${always}" };
  repair_denied    => { "${always}" };
  repair_timeout   => { "${always}" };

  persist_time     => "${persist}";
}


################################################
# Reporting bundles
################################################

#
# Create and send a report to the server
# This bundle takes 6 parameters :
# technique_name : the name of the technique, human readable
# status         : the status of the Component, among the following values
#    result_na
#    result_success
#    result_error
#    result_repaired
#    log_repaired (for logging only)
#    log_warn     (for logging only)
#    log_info     (for logging only)
#    log_debug    (for logging only)
#    log_trace    (for logging only)
# identifier     : the identifier of the current Rule and Directive
# component_name : the name of the component within the Technique
# component_key  : the value of the component reference variable (or None if undefined)
# message        : An explanation message understandable by a human
#
bundle agent rudder_common_report(technique_name, status, identifier, component_name, component_key, message)
{
  methods:
    "report" usebundle => rudder_common_report_index("${technique_name}", "${status}", "${identifier}", "${component_name}", "${component_key}", "${message}", "");
}

#
# Create and send a report to the server
# This bundle takes 7 parameters :
# technique_name : the name of the technique, human readable
# status         : the status of the Component, among the following values
#    result_na
#    result_success
#    result_error
#    result_repaired
#    log_repaired (for logging only)
#    log_warn     (for logging only)
#    log_info     (for logging only)
#    log_debug    (for logging only)
#    log_trace    (for logging only)
# identifier     : the identifier of the current Rule and Directive
# component_name : the name of the component within the Technique
# component_key  : the value of the component reference variable (or None if undefined)
# message        : An explanation message understandable by a human
# index          : the current index, that will distinguish two identical reports and ensure they are both sent
bundle agent rudder_common_report_index(technique_name, status, identifier, component_name, component_key, message, index)
{
  classes:
    changes_only::
      "send_reports" or => {
                            strcmp("${status}", "result_error") ,
                            strcmp("${status}", "result_repaired") ,
                            strcmp("${status}", "log_warn") ,
                            strcmp("${status}", "log_repaired") ,
                           };

  methods:
    # If we need to send a report, make sure we have sent the "StartRun" message first
    send_reports.!start_run_message_sent::
      "Send start message"
        usebundle => startExecution,
        action    => immediate;

  reports:
    full_compliance|send_reports::
      "@@${technique_name}@@${status}@@${identifier}@@${component_name}@@${component_key}@@${g.execRun}##${g.uuid}@#${message}"
        comment => "Reporting for ${technique_name} message ${message} for index ${index}";
}


#
# Automatically create reports based on existing classes starting by
# class_prefix (as defined by the body classes rudder_common_classes)
# Takes 6 parameters
# technique_name : the name of the technique, human readable
# class_prefix   : the prefix of a set of classes to reporting on (suffixes with "kept", "repaired", "error" or "noop")
# identifier     : the identifier of the current Rule and Directive
# component_name : the name of the component within the Technique
# component_key  : the value of the component reference variable (None if it does not exists)
# message_prefix : The begining of an explanation message understandable by a human
#
bundle agent rudder_common_reports_generic(technique_name, class_prefix, identifier, component_name, component_key, message_prefix)
{
  methods:
      "report"
        usebundle  => rudder_common_reports_generic_index("${technique_name}", "${class_prefix}", "${identifier}", "${component_name}", "${component_key}", "${message_prefix}", "");
}

#
# Automatically create reports based on existing classes starting by
# class_prefix (as defined by the body classes rudder_common_classes)
# Takes 7 parameters
# technique_name : the name of the technique, human readable
# class_prefix   : the prefix of a set of classes to reporting on (suffixes with "kept", "repaired" or "error")
# identifier     : the identifier of the current Rule and Directive
# component_name : the name of the component within the Technique
# component_key  : the value of the component reference variable (None if it does not exists)
# message_prefix : The begining of an explanation message understandable by a human
# index          : the current index, that will distinguish two identical reports and ensure they are both sent
#
bundle agent rudder_common_reports_generic_index(technique_name, class_prefix, identifier, component_name, component_key, message_prefix, index)
{
  methods:
      "na"
        usebundle  => rudder_common_report_index("${technique_name}", "result_na", "${identifier}", "${component_name}", "${component_key}", "${message_prefix} was not applicable", "${index}"),
        ifvarclass => "${class_prefix}_noop.!${class_prefix}_kept.!${class_prefix}_repaired.!${class_prefix}_error";

      "success"
        usebundle  => rudder_common_report_index("${technique_name}", "result_success", "${identifier}", "${component_name}", "${component_key}", "${message_prefix} was correct", "${index}"),
        ifvarclass => "${class_prefix}_kept.!${class_prefix}_repaired.!${class_prefix}_error";

      "repaired"
        usebundle  => rudder_common_report_index("${technique_name}", "result_repaired", "${identifier}", "${component_name}", "${component_key}", "${message_prefix} was repaired", "${index}"),
        ifvarclass => "${class_prefix}_repaired.!${class_prefix}_error";

      "error"
        usebundle  => rudder_common_report_index("${technique_name}", "result_error", "${identifier}", "${component_name}", "${component_key}", "${message_prefix} could not be repaired", "${index}"),
        ifvarclass => "${class_prefix}_error";
}

bundle agent startExecution
{
  vars:
    second_pass:: # This is necessary to work around a CFEngine bug that causes this to be defined all the time
      # Define a global class to show we have sent a "StartRun" report
      "dummy_string" string => "dummy_content",
        classes => always("start_run_message_sent");

  classes:
      # Dummy class to work around a CFEngine bug
      "second_pass" expression => "any";

  reports:
    cfengine_3::
      # Send the report and define a persistant class to store the last "heartbeat" time
      "@@Common@@log_info@@&TRACKINGKEY&@@common@@StartRun@@${g.execRun}##${g.uuid}@#Start execution with config [${g.rudder_node_config_id}]"
        classes => rudder_always_classes_persist("heartbeat_sent", "${g.heartbeat_interval}");
}

bundle agent endExecution
{
  reports:
    start_run_message_sent::
      "@@Common@@log_info@@&TRACKINGKEY&@@common@@EndRun@@${g.execRun}##${g.uuid}@#End execution with config [${g.rudder_node_config_id}]";

    rudder_promises_generated_error|no_update::
      "*********************************************************************************
* rudder-agent could not get an updated configuration from the policy server.   *
* This can be caused by a network issue, an unavailable server, or if this      *
* node was deleted from the Rudder root server.                                 *
* Any existing configuration policy will continue to be applied without change. *
*********************************************************************************";
}

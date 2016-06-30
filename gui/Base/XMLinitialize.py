# -*- coding: utf-8 -*-

#-------------------------------------------------------------------------------

# This file is part of Code_Saturne, a general-purpose CFD tool.
#
# Copyright (C) 1998-2016 EDF S.A.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
# Street, Fifth Floor, Boston, MA 02110-1301, USA.

#-------------------------------------------------------------------------------

"""
This module defines the XML data model in which the user defines the physical
options of the treated case.

This module contains the following classe:
- XMLinit
- XMLinitTestCase
"""

#-------------------------------------------------------------------------------
# Library modules import
#-------------------------------------------------------------------------------

import sys, unittest, re

#-------------------------------------------------------------------------------
# Application modules import
#-------------------------------------------------------------------------------

from code_saturne.Base.XMLvariables import Variables
from code_saturne.Base import Toolbox

from code_saturne.Pages.LocalizationModel import Zone, LocalizationModel
from code_saturne.Pages.OutputControlModel import OutputControlModel
from code_saturne.Pages.MobileMeshModel import MobileMeshModel
from code_saturne.Pages.TurbulenceModel import TurbulenceModel
from code_saturne.Pages.InitializationModel import InitializationModel
from code_saturne.Pages.TimeStepModel import TimeStepModel
from code_saturne.Pages.SteadyManagementModel import SteadyManagementModel
from code_saturne.Pages.FluidCharacteristicsModel import FluidCharacteristicsModel
from code_saturne.Pages.CoalCombustionModel import CoalCombustionModel
from code_saturne.Pages.ThermalScalarModel import ThermalScalarModel
from code_saturne.Pages.ElectricalModel import ElectricalModel
from code_saturne.Pages.GasCombustionModel import GasCombustionModel
from code_saturne.Pages.DarcyModel import DarcyModel
from code_saturne.Pages.AtmosphericFlowsModel import AtmosphericFlowsModel
from code_saturne.Pages.LagrangianModel import LagrangianModel
from code_saturne.Pages.ThermalRadiationModel import ThermalRadiationModel

#-------------------------------------------------------------------------------
# class XMLinit
#-------------------------------------------------------------------------------

class XMLinit(Variables):
    """
    This class initializes the XML contents of the case.
    """
    def __init__(self, case):
        """
        """
        self.case = case


    def initialize(self):
        """
        Verify that all Heading exist only once in the XMLDocument and
        create the missing heading.
        """
        msg = self.__initHeading()
        if msg:
            return msg

        self.__backwardCompatibility()

        # Initialization (order is important, see turbulenceModelsList method)

        self.node_models = self.case.xmlInitNode('thermophysical_models')
        node = self.node_models.xmlInitNode('velocity_pressure')
        self.setNewVariable(node, 'pressure')
        self.setNewVariable(node, 'velocity', dim = '3')
        self.setNewProperty(node, 'total_pressure')
        n = self.setNewProperty(node, 'yplus')
        n['support'] = 'boundary'
        n['label'] = 'Yplus'
        n = self.setNewProperty(node, 'effort')
        n['support'] = 'boundary'
        n['label'] = 'Efforts'
        if not node.xmlGetChildNode('property', name='effort_tangential'):
            n = self.setNewProperty(node, 'effort_tangential')
            n['label'] = 'Efforts, tangential'
            n['support'] = 'boundary'
            n.xmlInitNode('postprocessing_recording')['status']= "off"
        if not node.xmlGetChildNode('property', name='effort_normal'):
            n = self.setNewProperty(node, 'effort_normal')
            n['label'] = 'Efforts, normal'
            n['support'] = 'boundary'
            n.xmlInitNode('postprocessing_recording')['status']= "off"

        OutputControlModel(self.case).addDefaultWriter()
        OutputControlModel(self.case).addDefaultMesh()
        MobileMeshModel(self.case).getMethod()
        TurbulenceModel(self.case).getTurbulenceModel()

        # First Volume Zone definition for all cells -> initialization

        zones = LocalizationModel("VolumicZone", self.case).getZones()
        iok = 0
        for zone in zones:
            if zone.getLabel() == 'all_cells':
                iok = 1
        if iok == 0:
            zone = Zone("VolumicZone", self.case, label = 'all_cells', localization = 'all[]')
            LocalizationModel("VolumicZone", self.case).addZone(zone)
            zone = LocalizationModel("VolumicZone", self.case).getCodeNumberOfZoneLabel('all_cells')
            InitializationModel(self.case).getInitialTurbulenceChoice(zone)

        # Time step

        TimeStepModel(self.case).getTimeStep()
        TimeStepModel(self.case).getIterationsNumber()
        TimeStepModel(self.case).getTimePassing()

        # Thermodynamics definitinon

        m = FluidCharacteristicsModel(self.case)
        for tag in ('density',
                    'molecular_viscosity',
                    'specific_heat',
                    'thermal_conductivity'):
            m.getInitialValue(tag)

        # Calculation features

        SteadyManagementModel(self.case).getSteadyFlowManagement()
        ThermalScalarModel(self.case).getThermalScalarModel()
        CoalCombustionModel(self.case).getCoalCombustionModel()
        GasCombustionModel(self.case).getGasCombustionModel()
        ElectricalModel(self.case).getElectricalModel()
        ThermalRadiationModel(self.case).getRadiativeModel()
        DarcyModel(self.case).getDarcyModel()
        AtmosphericFlowsModel(self.case).getAtmosphericFlowsModel()
        LagrangianModel(self.case).getLagrangianStatus()

        return msg


    def __initHeading(self):
        """
        Create if necessary headings from the root element of the case.
        """
        msg = ""
        tagList = ('solution_domain',
                   'thermophysical_models',
                   'numerical_parameters',
                   'physical_properties',
                   'additional_scalars',
                   'boundary_conditions',
                   'analysis_control',
                   'calculation_management')

        for tag in tagList:
            nodeList = self.case.root().xmlInitChildNodeList(tag)

            if len(nodeList) > 1:
                msg = "There is an error with the use of the initHeading method. " \
                      "There is more than one occurence of the tag: \n\n" + tag +  \
                      "\n\nThe application will finish. Sorry."

        for tag in tagList:
            nodeList = self.case.xmlInitNodeList(tag)

            if len(nodeList) > 1:
                msg = "There is an error with the use of the initHeading method. " \
                      "There is more than one occurence of the tag: \n\n" + tag +  \
                      "\n\nThe application will finish. Sorry."

        return msg




    def __backwardCompatibility(self):
        """
        Change XML in order to ensure backward compatibility.
        """
        if self.case.root()["solver_version"]:
            vers = self.case.root()["solver_version"]
            history = vers.split(";")
            cur_vers = history[len(history) - 1]
            if history[len(history) - 1] == self.case['package'].version:
                self.__backwardCompatibilityCurrentVersion()
            else:
                self.__backwardCompatibilityOldVersion(cur_vers)
                self.__backwardCompatibilityCurrentVersion()
                his = ""
                for v in history:
                    his = his + v + ";"
                his = his + self.case['package'].version
                self.case.root().xmlSetAttribute(solver_version = his)

        else:
            vers = self.case['package'].version
            self.case.root().xmlSetAttribute(solver_version = vers)

            # apply all backwardCompatibility we don't know when it was create
            self.__backwardCompatibilityOldVersion("-1")
            self.__backwardCompatibilityCurrentVersion()


    def __backwardCompatibilityOldVersion(self, from_vers):
        """
        Change XML in order to ensure backward compatibility for old version
        """
        if from_vers == "-1":
            self.__backwardCompatibilityBefore_3_0()
            self.__backwardCompatibilityFrom_3_0()
            self.__backwardCompatibilityFrom_3_1()
            self.__backwardCompatibilityFrom_3_2()
            self.__backwardCompatibilityFrom_3_3()
        elif from_vers == "3.0":
            self.__backwardCompatibilityFrom_3_0()
            self.__backwardCompatibilityFrom_3_1()
            self.__backwardCompatibilityFrom_3_2()
            self.__backwardCompatibilityFrom_3_3()
        elif from_vers == "3.1":
            self.__backwardCompatibilityFrom_3_1()
            self.__backwardCompatibilityFrom_3_2()
            self.__backwardCompatibilityFrom_3_3()
        elif from_vers == "3.2":
            self.__backwardCompatibilityFrom_3_2()
            self.__backwardCompatibilityFrom_3_3()
        elif from_vers == "3.3":
            self.__backwardCompatibilityFrom_3_3()


    def __backwardCompatibilityBefore_3_0(self):
        """
        Change XML in order to ensure backward compatibility from 2.x to 3.0
        """
        for node in self.case.xmlGetNodeList('initial_value', 'zone'):
            node['zone_id'] = node['zone']

        for varNode in self.case.xmlGetNodeList('variable'):
            value = varNode.xmlGetDouble('solveur_precision')
            if value:
                varNode.xmlSetData('solver_precision', value)
                varNode.xmlRemoveChild('solveur_precision')

        XMLSolutionDomainNode = self.case.xmlInitNode('solution_domain')
        self.__XMLVolumicConditionsNode = XMLSolutionDomainNode.xmlInitNode('volumic_conditions')
        for node in self.__XMLVolumicConditionsNode.xmlGetNodeList('zone'):
            if node['id'] == None:
                node['id'] = node['name']

        oldnode = self.case.xmlGetNode('calcul_management')
        if oldnode:
            newnode = self.case.xmlInitNode('calculation_management')
            newnode.xmlChildsCopy(oldnode)
            oldnode.xmlRemoveNode()

        # Reference values
        XMLThermoPhysicalNode = self.case.xmlInitNode('thermophysical_models')
        self.__XMLVelocityPressureNode = XMLThermoPhysicalNode.xmlInitNode('velocity_pressure')
        self.__RefValuesNode = XMLThermoPhysicalNode.xmlInitNode('reference_values')

        nodeP = self.__XMLVelocityPressureNode.xmlGetNode('variable', name="pressure")
        if nodeP:
            value = nodeP.xmlGetDouble('reference_pressure')
            if value:
                self.__RefValuesNode.xmlSetData('pressure', value)
                nodeP.xmlRemoveChild('reference_pressure')

        nodeTurb = XMLThermoPhysicalNode.xmlInitNode('turbulence', 'model')

        for nodeInit in nodeTurb.xmlGetNodeList('initialization'):
            if nodeInit:
                value = nodeInit.xmlGetDouble('reference_velocity')
                if value:
                    self.__RefValuesNode.xmlSetData('velocity', value)
                    nodeInit.xmlRemoveChild('reference_velocity')

                value = nodeInit.xmlGetDouble('reference_length')
                if value:
                    self.__RefValuesNode.xmlSetData('length', value)
                    nodeInit.xmlRemoveChild('reference_length')

        for node in self.case.xmlGetNodeList('scalar'):
            value = node.xmlGetDouble('initial_value', zone_id="1")
            if value != None:
                formula = node['label'] + " = " + str(value) + ";"
                n = node.xmlInitChildNode('formula', zone_id="1")
                n.xmlSetTextNode(formula)
                node.xmlRemoveChild('initial_value', zone_id="1")

        # solver
        XMLNumParameterNode = self.case.xmlInitNode('numerical_parameters')
        node = XMLNumParameterNode.xmlGetNode('multigrid')
        if node:
            if node['status'] == "off":
                if nodeP:
                    nodeP.xmlInitNode('solver_choice', choice='conjugate_gradient')
            node.xmlRemoveNode()

        # hydrostatic pressure
        XMLPhysicalPropNode = self.case.xmlInitNode('physical_properties')
        node = XMLPhysicalPropNode.xmlGetNode('hydrostatic_pressure')
        if node:
            stat = node['status']
            XMLNumParameterNode.xmlInitNode('hydrostatic_pressure', status=stat)
            node.xmlRemoveNode()

        # Profiles
        compt = 0
        for node in self.case.xmlGetNodeList('profile'):
            nodeInit = node.xmlGetNode('x1')
            if nodeInit:
                node.xmlRemoveNode()
                compt = compt + 1
        if compt != 0:
            print("Profiles have been removed from your files due to  incompatibility")
            print("You must re-create them")

        # restart
        nodeR = self.case.xmlGetNode("start_restart")
        if nodeR:
            n = nodeR.xmlGetNode("restart", "status")
            if n:
                n.xmlRemoveNode()


    def __backwardCompatibilityFrom_3_0(self):
        """
        Change XML in order to ensure backward compatibility from 3.0 to 3.1
        """
        # Profiles
        for node in self.case.xmlGetNodeList('profile'):
            if node:
                n = node.xmlGetNode("output_type")
                if n == None:
                    freq = node.xmlGetInt("output_frequency")
                    if freq == -1:
                        node.xmlSetData('output_type', "end")
                    else:
                        node.xmlSetData('output_type', "frequency")


    def __backwardCompatibilityFrom_3_1(self):
        """
        Change XML in order to ensure backward compatibility from 3.1 to 3.2
        """
        # thermal scalar
        XMLThermoPhysicalNode = self.case.xmlInitNode('thermophysical_models')
        for phys in ['solid_fuels', 'gas_combustion', 'joule_effect', 'atmospheric_flows']:
            node = XMLThermoPhysicalNode.xmlInitNode(phys, 'model')
            mdl = node['model']
            if mdl and mdl != 'off':
                if phys != 'atmospheric_flows':
                    n = node.xmlGetNode('scalar', name="Enthalpy")
                    if n:
                        n.xmlRemoveNode()
                    ThermalScalarModel(self.case).setThermalModel('enthalpy')
                else:
                    if mdl == "dry":
                        n = node.xmlGetNode('scalar', name="potential_temperature")
                        if n:
                            n.xmlRemoveNode()
                        ThermalScalarModel(self.case).setThermalModel('potential_temperature')
                    elif mdl == "constant":
                        n = node.xmlGetNode('scalar', name="potential_temperature")
                        if n:
                            n.xmlRemoveNode()
                        n = node.xmlGetNode('scalar', name="liquid_potential_temperature")
                        if n:
                            n.xmlRemoveNode()
                        ThermalScalarModel(self.case).setThermalModel('off')
                    else:
                        n = node.xmlGetNode('scalar', name="liquid_potential_temperature")
                        if n:
                            n.xmlRemoveNode()
                        ThermalScalarModel(self.case).setThermalModel('liquid_potential_temperature')
        node = self.case.xmlGetNode('additional_scalars')
        n = node.xmlGetNode('scalar', type='thermal')
        if n:
            nth = XMLThermoPhysicalNode.xmlGetNode('thermal_scalar')
            nthvar = nth.xmlInitNode('scalar', 'type')
            nthvar['type']  = "thermal"
            nthvar['name']  = n['name']
            nthvar['label'] = n['label']
            nthvar.xmlChildsCopy(n)
            n.xmlRemoveNode()


    def __backwardCompatibilityFrom_3_2(self):
        """
        Change XML in order to ensure backward compatibility from 3.2 to 3.3
        """
        # thermal scalar
        XMLThermoPhysicalNode = self.case.xmlInitNode('thermophysical_models')
        for phys in ['solid_fuels', 'gas_combustion', 'joule_effect', 'atmospheric_flows', 'compressible_model']:
            node = XMLThermoPhysicalNode.xmlInitNode(phys, 'model')
            mdl = node['model']
            if mdl and mdl != 'off':
                if phys != 'atmospheric_flows' and phys != 'compressible_model':
                    n = node.xmlGetNode('scalar', name="Enthalpy")
                    if n:
                        n.xmlRemoveNode()
                    ThermalScalarModel(self.case).setThermalModel('enthalpy')
                elif phys == 'atmospheric_flows':
                    if (mdl == "dry"):
                        n = node.xmlGetNode('scalar', name="potential_temperature")
                        if n:
                            n.xmlRemoveNode()
                        ThermalScalarModel(self.case).setThermalModel('potential_temperature')
                    if (mdl == "humid"):
                        n = node.xmlGetNode('scalar', name="liquid_potential_temperature")
                        if n:
                            n.xmlRemoveNode()
                        ThermalScalarModel(self.case).setThermalModel('liquid_potential_temperature')
                else:
                    n = node.xmlGetNode('scalar', name="EnergieT")
                    if n:
                        n.xmlRemoveNode()
                    ThermalScalarModel(self.case).setThermalModel('total_energy')

        # properties
        XMLPhysicalPropNode = self.case.xmlInitNode('physical_properties')
        nodeF = XMLPhysicalPropNode.xmlInitNode('fluid_properties')
        for prop in ['density', 'molecular_viscosity', 'specific_heat',
                     'thermal_conductivity', 'volume_viscosity']:
            node = nodeF.xmlGetNode('property', name=prop)
            if node:
                if node['choice'] == 'user_law':
                    node['choice'] = 'variable'

        node = self.case.xmlGetNode('additional_scalars')
        n = node.xmlGetNode('scalar', type='thermal')
        if n:
            nth = XMLThermoPhysicalNode.xmlGetNode('thermal_scalar')
            nthvar = nth.xmlInitNode('variable', 'type')
            nthvar['type']  = "thermal"
            nthvar['name']  = n['name']
            nthvar['label'] = n['label']
            nthvar.xmlChildsCopy(n)
            n.xmlRemoveNode()

        # Replace scalar by variable in xml
        for phys in ['solid_fuels', 'gas_combustion', 'joule_effect', 'atmospheric_flows', 'compressible_model', 'thermal_scalar']:
            nodeP = XMLThermoPhysicalNode.xmlInitNode(phys, 'model')
            for node in nodeP.xmlGetNodeList('scalar'):
                name = node['name']
                label = node['label']
                dim = node['dimension']
                tpe = node['type']
                newnode = nodeP.xmlInitNode('variable', name=name)
                if label != None:
                    newnode['label'] = label
                if dim != None:
                    newnode['dimension'] = dim
                if tpe != None:
                    newnode['type'] = tpe
                newnode.xmlChildsCopy(node)
                node.xmlRemoveNode()

        self.scalar_node = self.case.xmlGetNode('additional_scalars')
        for node in self.scalar_node.xmlGetNodeList('scalar'):
            name = node['name']
            label = node['label']
            dim = node['dimension']
            tpe = node['type']
            newnode = self.scalar_node.xmlInitNode('variable', name=name)
            if label != None:
                newnode['label'] = label
            if dim != None:
                newnode['dimension'] = dim
            if tpe != None:
                newnode['type'] = tpe
            newnode.xmlChildsCopy(node)
            node.xmlRemoveNode()

        n = XMLThermoPhysicalNode.xmlGetNode('variable', type='thermal')
        if n:
            for nf in n.xmlGetNodeList('formula'):
                if nf:
                    status = nf["status"]
                    if not(status) or status == "on":
                        content = nf.xmlGetTextNode()
                        # Substitute only perfectly matching labels
                        pattern = '\\b' + n['label'] + '\\b'
                        content = re.sub(pattern, n['name'], content)
                        nf.xmlSetTextNode(content)


        # update velocity node
        nodeV = self.__XMLVelocityPressureNode.xmlGetNode('variable', name="velocity_U")
        if nodeV:
            nodeV['name'] = 'velocity'
            nodeV['dimension'] = '3'

            nodeTmp = self.__XMLVelocityPressureNode.xmlGetNode('variable', name="velocity_V")
            if nodeTmp:
                nodeTmp.xmlRemoveNode()
            nodeTmp = self.__XMLVelocityPressureNode.xmlGetNode('variable', name="velocity_W")
            if nodeTmp:
                nodeTmp.xmlRemoveNode()
        for node in self.case.xmlGetNodeList('profile'):
            if node:
                for n in node.xmlGetNodeList('var_prop'):
                    name = n['name']
                    if name in ["velocity_U", "velocity_V", "velocity_W"]:
                        if name == 'velocity_U':
                            component = '0'
                        if name == 'velocity_V':
                            component = '1'
                        if name == 'velocity_W':
                            component = '2'
                        name = 'velocity'
                        n['name'] = name
                        n['component'] = component
                    elif name != "velocity":
                        n['component'] = "0"

        for node in self.case.xmlGetNodeList('time_average'):
            if node:
                for n in node.xmlGetNodeList('var_prop'):
                    name = n['name']
                    if name in ["velocity_U", "velocity_V", "velocity_W"]:
                        if name == 'velocity_U':
                            component = '0'
                        if name == 'velocity_V':
                            component = '1'
                        if name == 'velocity_W':
                            component = '2'
                        name = 'velocity'
                        n['name'] = name
                        n['component'] = component
                    elif name != "velocity":
                        n['component'] = "0"

        for node in self.case.xmlGetNodeList('dirichlet'):
            if node:
                name = node['name']
                if name in ["velocity_U", "velocity_V", "velocity_W"]:
                    if name == 'velocity_U':
                        component = '0'
                    if name == 'velocity_V':
                        component = '1'
                    if name == 'velocity_W':
                        component = '2'
                    name = 'velocity'
                    node['name'] = name
                    node['component'] = component

        dicoName = [("NP_CP",                        "n_p_"),
                    ("XCH_CP",                       "x_p_coal_"),
                    ("XCK_CP",                       "x_p_char_"),
                    ("ENT_CP",                       "x_p_h_"),
                    ("XWT_CP",                       "x_p_wt_"),
                    ("Fr_MV1",                       "fr_mv1_"),
                    ("Fr_MV2",                       "fr_mv2_"),
                    ("Fr_HET_O2",                    "fr_het_o2"),
                    ("Fr_HET_CO2",                   "fr_het_co2"),
                    ("Fr_HET_H2O",                   "fr_het_h2o"),
                    ("FR_HCN",                       "x_c_hcn"),
                    ("FR_NO",                        "x_c_no"),
                    ("FR_NH3",                       "x_c_nh3"),
                    ("FR_CO2",                       "x_c_co2"),
                    ("Enth_Ox",                      "x_c_h_ox"),
                    ("FR_H20",                       "fr_h2o"),
                    ("FR_OXYD2",                     "fr_oxyd2"),
                    ("FR_OXYD3",                     "fr_oxyd3"),
                    ("Var_F1F2",                     "f1f2_variance"),
                    ("scalar",                       "user_"),
                    ("PotElecReal",                  "elec_pot_r"),
                    ("POT_EL_I",                     "elec_pot_i"),
                    ("YM_ESL",                       "esl_fraction"),
                    ("POT_VEC",                      "vec_potential_"),
                    ("Fra_MEL",                      "mixture_fraction"),
                    ("Var_FMe",                      "mixture_fraction_variance"),
                    ("Fra_GF",                       "fresh_gas_fraction"),
                    ("Fra_Mas",                      "mass_fraction"),
                    ("COYF_PP4",                     "mass_fraction_covariance"),
                    ("Var_FMa",                      "mass_fraction_variance"),
                    ("temperature_celsius",          "temperature"),
                    ("temperature_kelvin",           "temperature"),
                    ("TempK",                        "temperature"),
                    ("potential_temperature",        "temperature"),
                    ("liquid_potential_temperature", "temperature"),
                    ("component_R11",                "r11"),
                    ("component_R22",                "r22"),
                    ("component_R33",                "r33"),
                    ("component_R12",                "r12"),
                    ("component_R13",                "r13"),
                    ("component_R23",                "r23"),
                    ("turb_k",                       "k"),
                    ("turb_eps",                     "epsilon"),
                    ("turb_phi",                     "phi"),
                    ("turb_alpha",                   "alpha"),
                    ("turb_omega",                   "omega"),
                    ("nusa",                         "nu_tilda"),
                    ("volumic_viscosity",            "volume_viscosity")]
        dico = {}
        for (u,v) in dicoName:
            dico[u] = v
        for node in self.case.xmlGetNodeList('variable'):
            name = node["name"]
            if name:
                for key in dico.keys():
                    if name.startswith(key):
                        idx = name.find(key) + len(key)
                        node["name"] = dico[key] + name[idx:]
                        break

        XMLBoundaryNode = self.case.xmlInitNode('boundary_conditions')
        for node in XMLBoundaryNode.xmlGetNodeList('scalar'):
            name = node["name"]
            if name:
                for key in dico.keys():
                    if name.startswith(key):
                        idx = name.find(key) + len(key)
                        node["name"] = dico[key] + name[idx:]
                        break

        for node in self.case.xmlGetNodeList('var_prop'):
            name = node["name"]
            if name:
                for key in dico.keys():
                    if name.startswith(key):
                        idx = name.find(key) + len(key)
                        node["name"] = dico[key] + name[idx:]
                        break


        # update formula
        nth = XMLThermoPhysicalNode.xmlGetNode('thermal_scalar')
        nvel = XMLThermoPhysicalNode.xmlGetNode('velocity_pressure')

        for node in nvel.xmlGetNodeList('formula'):
            status = node["status"]
            if not(status) or status == "on":
                content = node.xmlGetTextNode()
                # Substitute only perfectly matching labels
                pattern = '\\bu\\b'
                content = re.sub(pattern, 'velocity[0]', content)
                pattern = '\\bv\\b'
                content = re.sub(pattern, 'velocity[1]', content)
                pattern = '\\bw\\b'
                content = re.sub(pattern, 'velocity[2]', content)
                pattern = '\\bP\\b'
                content = re.sub(pattern, 'pressure', content)
                node.xmlSetTextNode(content)

        for node in nth.xmlGetNodeList('formula'):
            status = node["status"]
            if not(status) or status == "on":
                content = node.xmlGetTextNode()
                # Substitute only perfectly matching labels
                pattern = '\\bT\\b'
                content = re.sub(pattern, 'temperature', content)
                pattern = '\\btemperature_celsius\\b'
                content = re.sub(pattern, 'temperature', content)
                pattern = '\\btemperature_kelvin\\b'
                content = re.sub(pattern, 'temperature', content)
                node.xmlSetTextNode(content)

        for node in XMLThermoPhysicalNode.xmlGetNodeList('formula'):
            status = node["status"]
            if not(status) or status == "on":
                content = node.xmlGetTextNode()
                nodeas = self.case.xmlGetNode('additional_scalars')
                nth = nodeas.xmlGetNode('scalar', type='thermal')
                if nth:
                    # Substitute only perfectly matching labels
                    pattern = '\\b' + nth['label'] + '\\b'
                    content = re.sub(pattern, nth['name'], content)
                node.xmlSetTextNode(content)

        for node in XMLPhysicalPropNode.xmlGetNodeList('formula'):
            nodeas = self.case.xmlGetNode('additional_scalars')
            nth = nodeas.xmlGetNode('scalar', type='thermal')
            if nth:
                content = node.xmlGetTextNode()
                # Substitute only perfectly matching labels
                pattern = '\\b' + nth['label'] + '\\b'
                content = re.sub(pattern, nth['name'], content)
                node.xmlSetTextNode(content)

        XMLAddScalar = self.case.xmlGetNode('additional_scalars')
        for node in XMLAddScalar.xmlGetNodeList('variable'):
            nfor = node.xmlGetNode('formula')
            if nfor:
                content = nfor.xmlGetTextNode()
                # Substitute only perfectly matching labels
                pattern = '\\b' + node['label'] + '\\b'
                content = re.sub(pattern, node['name'], content)
                nfor.xmlSetTextNode(content)

        for node in XMLBoundaryNode.xmlGetNodeList('turbulence'):
            if node["choice"] == "formula":
                nf = node.xmlGetNode('formula')
                if nf:
                    content = nf.xmlGetTextNode()
                    # Substitute only perfectly matching labels
                    pattern = '\\beps\\b'
                    content = re.sub(pattern, 'epsilon', content)
                    nf.xmlSetTextNode(content)

        # TODO update formula BC for turbulence
        #for node in XMLBoundaryNode.xmlGetNodeList('turbulence'):
        #    if node["choice"] = "formula":
        #        nf = node.xmlGetNode('formula')
        #        for key in dico.keys():
        #            if name.startswith(key):
        #                idx = name.find(key) + len(key)
        #                node["name"] = dico[key] + name[idx:]
        #                break

        dicoProp = [("Rho",                          "density"),
                    ("turb_viscosity",               "turbulent_viscosity"),
                    ("smagorinsky_constant",         "smagorinsky_constant^2"),
                    ("Temperature",                  "temperature"),
                    ("YM_Fuel",                      "ym_fuel"),
                    ("YM_Oxyd",                      "ym_oxyd"),
                    ("YM_Prod",                      "ym_prod"),
                    ("Mas_Mol",                      "molar_mass"),
                    ("T.SOURCE",                     "source_term"),
                    ("RHOL0",                        "rho_local_"),
                    ("TEML0",                        "temperature_local_"),
                    ("FMEL0",                        "ym_local_"),
                    ("FMAL0",                        "w_local_"),
                    ("AMPL0",                        "amplitude_local_"),
                    ("TSCL0",                        "chemical_st_local_"),
                    ("MAML0",                        "molar_mass_local_"),
                    ("Temp_GAZ",                     "t_gas"),
                    ("ROM_GAZ",                      "rho_gas"),
                    ("YM_CHx1m",                     "ym_chx1m"),
                    ("YM_CHx2m",                     "ym_chx2m"),
                    ("YM_CO",                        "ym_co"),
                    ("YM_H2S",                       "ym_h2s"),
                    ("YM_H2",                        "ym_h2"),
                    ("YM_HCN",                       "ym_hcn"),
                    ("YM_NH3",                       "ym_nh3"),
                    ("YM_O2",                        "ym_o2"),
                    ("YM_CO2",                       "ym_co2"),
                    ("YM_H2O",                       "ym_h2o"),
                    ("YM_SO2",                       "ym_so2"),
                    ("YM_N2",                        "ym_n2"),
                    ("XM",                           "xm"),
                    ("EXP1",                         "exp1"),
                    ("EXP2",                         "exp2"),
                    ("EXP3",                         "exp3"),
                    ("EXP4",                         "exp4"),
                    ("EXP5",                         "exp5"),
                    ("F_HCN_DEV",                    "f_hcn_dev"),
                    ("F_HCN_HET",                    "f_hcn_het"),
                    ("F_NH3_DEV",                    "f_nh3_dev"),
                    ("F_NH3_HET",                    "f_nh3_het"),
                    ("F_NO_HCN",                     "f_no_hcn"),
                    ("F_NO_NH3",                     "f_no_nh3"),
                    ("F_NO_HET",                     "f_no_het"),
                    ("F_NO_THE",                     "f_no_the"),
                    ("C_NO_HCN",                     "c_no_hcn"),
                    ("C_NO_NH3",                     "c_no_nh3"),
                    ("F_HCN_RB",                     "f_hcn_rb"),
                    ("C_NO_RB",                      "c_no_rb"),
                    ("EXP_RB",                       "exp_rb"),
                    ("Temp_CP",                      "t_p_"),
                    ("Frm_CP",                       "x_p_"),
                    ("Rho_CP",                       "rho_p_"),
                    ("Dia_CK",                       "diam_p_"),
                    ("Ga_DCH",                       "dissapear_rate_p_"),
                    ("Ga_DV1",                       "m_transfer_v1_p_"),
                    ("Ga_DV2",                       "m_transfer_v2_p_"),
                    ("Ga_HET_O2",                    "het_ts_o2_p_"),
                    ("Ga_HET_CO2",                   "het_ts_co2_p"),
                    ("Ga_HET_H2O",                   "het_ts_h2o_p"),
                    ("Ga_HET",                       "het_ts_coal"),
                    ("Ga_SEC",                       "dry_ts_p"),
                    ("Bilan_C",                      "x_carbone"),
                    ("Bilan_O",                      "x_oxygen"),
                    ("Bilan_H",                      "x_hydrogen"),
                    ("PuisJoul",                     "joule_power"),
                    ("Cour_re",                      "current_re_"),
                    ("CouImag",                      "current_im_"),
                    ("For_Lap",                      "laplace_force_"),
                    ("Coef_Abso",                    "absorption_coeff"),
                    ("c_NO_HCN",                     "radiation_source"),
                    ("Sigma",                        "elec_sigma"),
                    ("IntLuminance_4PI",             "intensity"),
                    ("volumic_viscosity",            "volume_viscosity")]

        dicoP = {}
        for (u,v) in dicoProp:
            dicoP[u] = v
        for node in self.case.xmlGetNodeList('property'):
            name = node["name"]
            if name:
                for key in dicoP.keys():
                    if name.startswith(key) and name != "smagorinsky_constant^2":
                        idx = name.find(key) + len(key)
                        node["name"] = dicoP[key] + name[idx:]
                        break

        for node in self.case.xmlGetNodeList('var_prop'):
            name = node["name"]
            if name:
                for key in dicoP.keys():
                    if name.startswith(key) and name != "smagorinsky_constant^2":
                        idx = name.find(key) + len(key)
                        node["name"] = dicoP[key] + name[idx:]
                        break

        nodeCompress = XMLThermoPhysicalNode.xmlGetNode('compressible_model')
        if nodeCompress['model'] and nodeCompress['model'] != "off":
            n = nodeCompress.xmlGetNode("property", name = "density")
            if n:
                ndens = XMLPhysicalPropNode.xmlGetNode('property', name='density')
                ndens.xmlChildsCopy(n)
                n.xmlRemoveNode()
        for node in XMLPhysicalPropNode.xmlGetNodeList('property'):
            n = node.xmlGetNode('formula')
            if n:
                f = n.xmlGetTextNode()
                if f != None:
                    # Substitute only perfectly matching labels
                    pattern = '\\brho\\b'
                    content = re.sub(pattern, 'density', content)
                    pattern = '\\bmu\\b'
                    content = re.sub(pattern, 'molecular_viscosity', content)
                    pattern = '\\bcp\\b'
                    content = re.sub(pattern, 'specific_heat', content)
                    pattern = '\\blambda\\b'
                    content = re.sub(pattern, 'thermal_conductivity', content)
                    pattern = '\\bviscv\\b'
                    content = re.sub(pattern, 'volume_viscosity', content)
                    n.xmlSetTextNode(f)


    def __backwardCompatibilityFrom_3_3(self):
        """
        Change XML in order to ensure backward compatibility from 3.3 to 4.0
        """
        XMLAnaControl = self.case.xmlGetNode('analysis_control')
        self.scalar_node = self.case.xmlGetNode('additional_scalars')
        for node in self.scalar_node.xmlGetNodeList('variable'):
            name = node['name']
            label = node['label']
            if name == None:
                node['name'] = label
            if label == None:
                node['label'] = name
            for n in XMLAnaControl.xmlGetNodeList('var_prop'):
                if n['name'] == name:
                    n['name'] = node['name']
            for n in node.xmlGetNodeList('formula'):
                if n:
                    content = n.xmlGetTextNode()
                    # Substitute only perfectly matching labels
                    pattern = '\\b' + name + '\\b'
                    content = re.sub(pattern, name, content)
                    n.xmlSetTextNode(content)

        XMLBoundaryNode = self.case.xmlInitNode('boundary_conditions')
        for node in XMLBoundaryNode.xmlGetNodeList('scalar'):
            name = node['name']
            label = node['label']
            if name == None:
                node['name'] = label
            if label == None:
                node['label'] = name

        XMLThermoPhysicalModel = self.case.xmlGetNode('thermophysical_models')
        XMLAleMethod = XMLThermoPhysicalModel.xmlInitChildNode('ale_method', 'status')
        if XMLAleMethod:
            for node in XMLAleMethod.xmlGetNodeList('formula'):
                if node:
                    content = node.xmlGetTextNode()
                    # Substitute only perfectly matching labels
                    pattern = '\\bmesh_vi1\\b'
                    content = re.sub(pattern, "mesh_viscosity_1", content)
                    pattern = '\\bmesh_vi2\\b'
                    content = re.sub(pattern, "mesh_viscosity_2", content)
                    pattern = '\\bmesh_vi3\\b'
                    content = re.sub(pattern, "mesh_viscosity_3", content)
                    node.xmlSetTextNode(content)

        for node in self.case.xmlGetNodeList('time_average'):
            if node:
                time_node = node.xmlGetNode("time_start")
                if not time_node:
                    node.xmlSetData('time_start', -1.)

        # update velocity node
        XMLThermoPhysicalNode = self.case.xmlInitNode('thermophysical_models')
        self.__XMLVelocityPressureNode = XMLThermoPhysicalNode.xmlInitNode('velocity_pressure')
        nodeV = self.__XMLVelocityPressureNode.xmlGetNode('variable', name="velocity")
        if nodeV:
            if nodeV['label'] == 'VelocityX':
                nodeV['label'] = 'Velocity'
        #update input_thermal_flux
        nth = XMLThermoPhysicalNode.xmlGetNode('thermal_scalar')
        if nth:
            node = nth.xmlGetNode('property', name="input_thermal_flux")
            node2 = nth.xmlGetNode('property', name="thermal_flux")
            if node2 and node:
                node.xmlRemoveNode()
            elif node:
                node['name'] = "thermal_flux"


    def __backwardCompatibilityCurrentVersion(self):
        """
        Change XML in order to ensure backward compatibility.
        """
        XMLThermoPhysicalModelNode = self.case.xmlGetNode('thermophysical_models')
        n = XMLThermoPhysicalModelNode.xmlGetNode('variable', type='thermal')
        if n:
            # try to get turbulent_flux_model
            ntfm = n.xmlGetString("turbulent_flux_model")
            if not ntfm:
                n.xmlSetData('turbulent_flux_model', "SGDH")

        # replace label by name in each formula
        for node in self.case.xmlGetNodeList('formula'):
            if node:
                status = node["status"]
                if not(status) or status == "on":
                    content = node.xmlGetTextNode()
                    for n in self.case.xmlGetNodeList('variable', 'name', 'label'):
                        # Substitute only perfectly matching labels
                        pattern = '\\b' + n['label'] + '\\b'
                        content = re.sub(pattern, n['name'], content)
                    node.xmlSetTextNode(content)

        for node in self.case.xmlGetNodeList('variable'):
            variance = node.xmlGetString('variance')
            if variance:
                for n in self.case.xmlGetNodeList('variable', 'name', 'label'):
                    if variance == n['label']:
                        node.xmlSetData('variance', n['name'])
                        break

        # update mesh velocity node
        # Note: it is important to do this only after updating formulas and
        #       not before, to apply updates in the order if code changes.
        XMLThermoPhysicalModel = self.case.xmlGetNode('thermophysical_models')
        XMLAleMethod = XMLThermoPhysicalModel.xmlGetChildNode('ale_method', 'status')
        if XMLAleMethod:
            nodeV = XMLAleMethod.xmlGetNode('variable', name="mesh_velocity_U")
            if nodeV:
                nodeV['name'] = 'mesh_velocity'
                nodeV['label'] = 'Mesh Velocity'
                nodeV['dimension'] = '3'

                nodeTmp = XMLAleMethod.xmlGetNode('variable', name="mesh_velocity_V")
                if nodeTmp:
                    nodeTmp.xmlRemoveNode()
                nodeTmp = XMLAleMethod.xmlGetNode('variable', name="mesh_velocity_W")
                if nodeTmp:
                    nodeTmp.xmlRemoveNode()

        # replace bounce by part_symmetry for lagrangian model on
        # symmetry
        XMLBoundaryNode = self.case.xmlInitNode('boundary_conditions')
        for node in XMLBoundaryNode.xmlGetNodeList('symmetry'):
            nn = node.xmlGetNode("particles")
            if nn:
                if nn["choice"] == "bounce":
                    nn["choice"] = "part_symmetry"

        # add lagrangian writer if needed
        XMLLagrangianModel = self.case.xmlGetNode('lagrangian')
        if XMLLagrangianModel:
            mdl = XMLLagrangianModel["model"]
            if mdl != "off":
                XMLAnaControl = self.case.xmlGetNode('analysis_control')
                node_out = XMLAnaControl.xmlGetNode('output')
                nn = node_out.xmlGetNode('writer', 'label', id = "-3")
                if nn == None:
                    nodeL = node_out.xmlInitNode('writer', id = "-3", label = 'particles')
                    nodeL.xmlInitNode('frequency', period = 'none')
                    nodeL.xmlInitNode('output_at_end', status = 'on')
                    nodeL.xmlInitNode('format', name = 'ensight', options = 'binary')
                    nodeL.xmlInitNode('directory', name = 'postprocessing')
                    nodeL.xmlInitNode('time_dependency', choice = 'transient_connectivity')

                nn = node_out.xmlGetNode('writer', 'label', id = "-4")
                if nn == None:
                    nodeT = node_out.xmlInitNode('writer', id = "-4", label = 'trajectories')
                    nodeT.xmlInitNode('frequency', period = 'none')
                    nodeT.xmlInitNode('output_at_end', status = 'on')
                    nodeT.xmlInitNode('format', name = 'ensight', options = 'binary')
                    nodeT.xmlInitNode('directory', name = 'postprocessing')
                    nodeT.xmlInitNode('time_dependency', choice = 'fixed_mesh')

                nn = node_out.xmlGetNode('mesh', id = "-3")
                if nn == None:
                    node1 = node_out.xmlInitNode('mesh', id = "-3",
                                                 label = 'particles',
                                                 type = 'particles')
                    node1.xmlInitNode('all_variables', status = 'on')
                    node1.xmlInitNode('location')
                    node1.xmlSetData('location','all[]')
                    node1.xmlInitNode('density')
                    node1.xmlSetData('density', 1)
                    node1.xmlInitNode('writer', id = '-3')

        lst = self.case.xmlGetNodeList('external_coupling')
        if len(lst) > 1:
            for i in range(len(lst)):
                lst[i].xmlRemoveNode()


#-------------------------------------------------------------------------------
# XMLinit test case
#-------------------------------------------------------------------------------


class XMLinitTestCase(unittest.TestCase):
    """
    """
    def setUp(self):
        """
        This method is executed before all "check" methods.
        """
        from code_saturne.Base import XMLengine
        Toolbox.GuiParam.lang = 'en'
        self.doc = XMLengine.XMLDocument("")
        self.case = XMLengine.Case(None)


    def tearDown(self):
        """
        This method is executed after all "check" methods.
        """
        del self.case
        del self.doc


    def xmlNodeFromString(self, string):
        """Private method to return a xml node from string"""
        return self.doc.parseString(string).root()


    def checkXMLinitInstantiation(self):
        """
        Check whether the Case class could be instantiated
        """
        xmldoc = None
        xmldoc = XMLinit(self.case)
        assert xmldoc != None, 'Could not instantiate XMLinit'


    def checkInitHeading(self):
        """
        Check whether the headings markups could be initialized
        """
        doc = \
        '<Code_Saturne_GUI case="" study="" version="1.0">'\
        '<solution_domain/>'\
        '<thermophysical_models>'\
                '<velocity_pressure>'\
                        '<variable label="Pressure" name="pressure"/>'\
                        '<variable label="Velocity" name="velocity"/>'\
                        '<property label="total_pressure" name="total_pressure"/>'\
                '</velocity_pressure>'\
                '<turbulence model="k-epsilon">'\
                        '<variable label="TurbEner" name="turb_k"/>'\
                        '<variable label="Dissip" name="turb_eps"/>'\
                        '<property label="TurbVisc" name="turbulent_viscosity"/>'\
                        '<initialization choice="reference_velocity">'\
                                '<reference_velocity>1.0</reference_velocity>'\
                        '</initialization>'\
                '</turbulence>'\
                '<initialization>'\
                        '<zone name="1">0</zone>'\
                '</initialization>'\
                '<thermal_scalar model="off"/>'\
                '<gas_combustion model="off"/>'\
                '<solid_fuels model="off"/>'\
                '<joule_effect model="off"/>'\
                '<radiative_transfer model="off"/>'\
        '</thermophysical_models>'\
        '<numerical_parameters/>'\
        '<physical_properties>'\
                '<fluid_properties>'\
                        '<property choice="constant" label="Density" name="density">'\
                                '<listing_printing status="off"/>'\
                                '<postprocessing_recording status="off"/>'\
                                '<initial_value>1.17862</initial_value>'\
                        '</property>'\
                        '<property choice="constant" label="LamVisc" name="molecular_viscosity">'\
                                '<listing_printing status="off"/>'\
                                '<postprocessing_recording status="off"/>'\
                                '<initial_value>1.83e-05</initial_value>'\
                        '</property>'\
                        '<property choice="constant" label="SpecHeat" name="specific_heat">'\
                                '<listing_printing status="off"/>'\
                                '<postprocessing_recording status="off"/>'\
                                '<initial_value>1017.24</initial_value>'\
                        '</property>'\
                        '<property choice="constant" label="ThermalCond" name="thermal_conductivity">'\
                                '<listing_printing status="off"/>'\
                                '<postprocessing_recording status="off"/>'\
                                '<initial_value>0.02495</initial_value>'\
                        '</property>'\
                '</fluid_properties>'\
        '</physical_properties>'\
        '<additional_scalars/>'\
        '<boundary_conditions/>'\
        '<analysis_control>'\
                '<time_parameters>'\
                        '<time_step_ref>0.1</time_step_ref>'\
                        '<property label="CourantNb" name="courant_number">'\
                        '<property label="FourierNb" name="fourier_number">'\
                '</time_parameters>'\
        '</analysis_control>'\
        '<calculation_management/>'\
        '</Code_Saturne_GUI>'

        XMLinit(self.case).initialize()

        assert self.case.root() == self.xmlNodeFromString(doc), \
               'Could not use the constructor of the XMLinit class'


def suite():
    testSuite = unittest.makeSuite(XMLinitTestCase, "check")
    return testSuite


def runTest():
    print("XMLinitTestCase to be completed...")
    runner = unittest.TextTestRunner()
    runner.run(suite())


#-------------------------------------------------------------------------------
# End of XMLinit
#-------------------------------------------------------------------------------

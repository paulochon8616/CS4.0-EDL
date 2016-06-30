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
This module defines a Lightweight XML constructor and reader.
It provides a management of the XML document, which reflets the treated case.

This module defines the following classes:
- Dico
- XMLElement
- _Document (obsolete since Python 2.3)
- XMLDocument
- Case
- XMLDocumentTestCase
"""

#-------------------------------------------------------------------------------
# String for the root node of the xml document from the case
#-------------------------------------------------------------------------------

rootNode = None

#-------------------------------------------------------------------------------
# Library modules import
#-------------------------------------------------------------------------------

import os, sys, string, unittest, logging
from types import UnicodeType
from xml.dom.minidom import Document, parse, parseString, Node
from xml.sax.handler import ContentHandler
from xml.sax import make_parser

#-------------------------------------------------------------------------------
# Application modules import
#-------------------------------------------------------------------------------

from code_saturne.Base.Toolbox import GuiParam

#-------------------------------------------------------------------------------
# Third-party modules
#-------------------------------------------------------------------------------

from PyQt4.QtCore import QObject, SIGNAL

#-------------------------------------------------------------------------------
# log config
#-------------------------------------------------------------------------------

logging.basicConfig()
log = logging.getLogger("XMLengine")
#log.setLevel(logging.NOTSET)
log.setLevel(GuiParam.DEBUG)

#-------------------------------------------------------------------------------
# Checker of XML file syntax
#-------------------------------------------------------------------------------

def xmlChecker(filename):
    """Try to open the xml file, and return a message if an error occurs.

    @param filename name of the file of parameters ith its absolute path
    @return m error message
    """
    m = ""

    try:
        p = make_parser()
        p.setContentHandler(ContentHandler())
        p.parse(filename)
    except Exception as e:
        f = os.path.basename(filename)
        m = "%s file reading error. \n\n"\
            "This file is not in accordance with XML specifications.\n\n"\
            "The parsing syntax error is:\n\n%s" % (f, e)

    return m

#-------------------------------------------------------------------------------
# Simple class wich emulate a basic dictionary, but allows to make
# everytimes verification on values and keys
#-------------------------------------------------------------------------------

class Dico:
    """
    This define a simple class in order to store informations about the case.
    These informations are usefull only for the current session, and are
    forgotten for the next one.
    """
    def __init__(self):
        """
        Create a dictionary and the associated key.
        """
        self.data = {}

        self.data['new']              = ""
        self.data['saved']            = "yes"
        self.data['xmlfile']          = ""
        self.data['mesh_path']        = ""
        self.data['user_src_path']    = ""
        self.data['data_path']        = ""
        self.data['resu_path']        = ""
        self.data['scripts_path']     = ""
        self.data['relevant_subdir']  = "no"
        self.data['case_path']        = ""
        self.data['runcase']          = False
        self.data['batch_type']       = ""
        self.data['no_boundary_conditions'] = False
        self.data['salome']           = False
        self.data['package']          = None
        self.data['current_page']     = ""
        self.data['current_index']    = None
        self.data['current_tab']      = -1
        self.data['undo']             =  []
        self.data['redo']             =  []
        self.data['probes']           = None

    def _errorExit(self, msg):
        """
        """
        print('CASE DICO ERROR')
        raise ValueError(msg)


    def __setitem__(self, key, name):
        """
        Store values in the data dictionary when the key exists
        in the  dictionary.
        """
        if hasattr(self, 'data'):
            if key in self.data:
                self.data[key] = name
            else:
                msg = "There is an error in the use of the dictionary "+ \
                      "with the key named: " + key + ". \n" + \
                      "The application will finish.\n" \
                      "Please contact the development team."

                print(self._errorExit(msg))


    def __getitem__(self, key):
        """
        Extraction of informations from the data dictionary.
        """
        if hasattr(self, 'data'):
            if key in self.data:
                return self.data[key]
            else:
                return None


    def printDico(self):
        """
        Simple tool wich print on the current terminal the contents of the dico.
        """
        if hasattr(self, 'data'):
            for i in list(self.data.keys()):
                print("%s -> %s" % (i, self.data[i]))


#-------------------------------------------------------------------------------
# Lightweight XML constructor and reader
#-------------------------------------------------------------------------------


enc = "utf-8"


def _encode(v):
    """
    return a byte string. This function handles the Unicode encoding.
    minidom handles only byte strings, see: http://evanjones.ca/python-utf8.html
    """
    if isinstance(v, UnicodeType):
        v = v.encode(enc)
    return v


class XMLElement:
    """
    """
    def __init__(self, doc, el, case):
        """
        Constructor.
        """
        self.doc = doc
        self.el  = el
        self.ca  = case


    def _errorExit(self, msg):
        """
        """
        print('XML ERROR')
        raise ValueError(msg)


    def toString(self):
        """
        Print the XMLElement node to a simple string (without \n and \t).
        Unicode characters are encoded.
        """
        return self.el.toxml(enc)


    def toUnicodeString(self):
        """
        Print the XMLElement node to an unicode string (without \n and \t).
        Unicode string are decoded if it's possible by the standard output,
        if not unicode characters are replaced by '?' character.
        Warning: do not use this method for comparison purpose!
        """
        unicode_obj = self.el.toxml()
        try:
            return unicode_obj.encode("utf-8", 'replace')
        except:
            return unicode_obj.encode(sys.stdout.encoding, 'replace')


    def __str__(self):
        """
        Print the XMLElement node with \n and \t.
        Unicode string are decoded if it's possible by the standard output,
        if not unicode characters are replaced by '?' character.
        Warning: do not use this method for comparison purpose!
        """
        unicode_obj = self.el.toprettyxml()
        try:
            return unicode_obj.encode("utf-8", 'replace')
        except:
            return unicode_obj.encode(sys.stdout.encoding, 'replace')


    def __xmlLog(self):
        """Convenient method for log"""
        if self.el.hasChildNodes() and len(self.el.childNodes) > 1:
            return "\n" + self.__str__()
        else:
            return self.toUnicodeString()


    def _inst(self, el):
        """
        Transform a Element node to an instance of the XMLElement class.
        """
        return XMLElement(self.doc, el, self.ca)


    def xmlCreateAttribute(self, **kwargs):
        """
        Set attributes to a XMLElement node, only if these attributes
        does not allready exist.
        """
        if self.ca: self.ca.modified()

        for attr, value in list(kwargs.items()):
            if not self.el.hasAttribute(attr):
                self.el.setAttribute(attr, _encode(str(value)))

        log.debug("xmlCreateAttribute-> %s" % self.__xmlLog())


    def xmlGetAttributeDictionary(self):
        """
        Return the dictionary of the XMLElement node attributes.
        """
        d = {}
        if self.el.nodeType == Node.ELEMENT_NODE:
            if self.el.hasAttributes():
                attrs = self.el._get_attributes()
                a_names = list(attrs.keys())
                a_names.sort()
                for a_name in a_names:
                    d[a_name] = attrs[a_name].value
        return d


    def xmlGetAttribute(self, attr):
        """
        Return the value of the XMLElement node attribute.
        Crash if the searched attribute does not exist.
        """
        if not self.el.hasAttribute(attr):
            node = self.__str__()
            attr = attr.encode(sys.stdout.encoding,'replace')
            msg = "There is an error in with the elementNode: \n\n" \
                  + node + "\n\nand the searching attribute: \n\n" \
                  + attr + "\n\nThe application will finish."
            self._errorExit(msg)
        else:
            a = self.el.getAttributeNode(attr)

        return _encode(a.value)


    def xmlSetAttribute(self, **kwargs):
        """
        Set several attribute (key=value) to a node
        """
        if self.ca: self.ca.modified()

        for attr, value in list(kwargs.items()):
            self.el.setAttribute(attr, _encode(str(value)))

        log.debug("xmlSetAttribute-> %s" % self.__xmlLog())


    def xmlDelAttribute(self, attr):
        """
        Delete the XMLElement node attribute
        """
        if self.ca: self.ca.modified()

        if self.el.hasAttribute(attr):
            self.el.removeAttribute(attr)

        log.debug("xmlDelAttribute-> %s %s" % (attr, self.__xmlLog()))


    def __getitem__(self, attr):
        """
        Return the XMLElement attribute's value
        with a dictionary syntaxe: node['attr']
        Return None if the searched attribute does not exist.
        """
        a = self.el.getAttributeNode(attr)
        if a:
            return _encode(a.value)
        return None


    def __setitem__(self, attr, value):
        """
        Set a XMLElement attribute an its value
        with a dictionary syntaxe: node['attr'] = value
        """
        if self.ca: self.ca.modified()
        self.el.setAttribute(attr, _encode(str(value)))

        log.debug("__setitem__-> %s" % self.__xmlLog())


    def __delitem__(self, name):
        """
        Delete a XMLElement attribute with a dictionary syntaxe: del node['attr']
        """
        if self.ca: self.ca.modified()
        self.xmlDelAttribute(name)

        #log.debug("__delitem__-> %s" % self.__xmlLog())


    def xmlSortByTagName(self):
        """
        Return a dictionary which keys are the name of the node.
        """
        d = {}
        for node in self.el.childNodes:
            if node.nodeType == Node.ELEMENT_NODE:
                dd = self._inst(node).xmlGetAttributeDictionary()
                key = node.tagName
                for k in list(dd.keys()): key = key + (k+dd[k])
                d[key] = self._inst(node)
            elif node.nodeType == Node.TEXT_NODE:
                try:
                    k = float(node.data)
                except:
                    k = node.data
                d[k] = self._inst(node)
        return d


    def __cmp__(self, other):
        """
        Return 0 if two XMLElement are the same, return 1 otherwise.
        """
        if not other:
            return 1
        if not isinstance(other, XMLElement):
            return 1
        if self.el.nodeType == Node.ELEMENT_NODE:
            if self.el.tagName != other.el.tagName:
                return 1
        elif self.el.nodeType == Node.TEXT_NODE:
            try:
                a = float(self.el.data)
                b = float(other.el.data)
            except:
                a = self.el.data
                b = other.el.data
            if a != b:
                return 1
        if self.xmlGetAttributeDictionary() != other.xmlGetAttributeDictionary():
            return 1
        d1 = self.xmlSortByTagName()
        d2 = other.xmlSortByTagName()
        l1 = list(d1.keys())
        l2 = list(d2.keys())
        l1.sort()
        l2.sort()
        if l1 != l2:
            return 1
        if self.el.childNodes and other.el.childNodes:
            for key in list(d1.keys()):
                if d1[key] != d2[key]:
                    return 1
        return 0


    def _nodeList(self, tag, *attrList, **kwargs):
        """
        Return a list of Element (and not XMLElement)!
        """
        nodeList = []

        # Get the nodes list
        #
        nodeL = self.el.getElementsByTagName(tag)

        # If there is a precision for the selection
        #
#TRYME
##        for attr in attrList:
##            for node in nodeL:
##                if node.hasAttribute(attr) and node not in nodeList:
##                    nodeList.append(node)

##        if attrList and kwargs:
##            nodeL = nodeList
##            nodeList = []

##        for k, v in kwargs.items():
##            for node in nodeL:
##                if node.getAttribute(k) == v and node not in nodeList:
##                    nodeList.append(node)

        for node in nodeL:
            iok = 0
            for attr in attrList:
                if node.hasAttribute(str(attr)):
                    iok = 1
                else:
                    iok = 0
                    break
            if iok: nodeList.append(node)

        if attrList and kwargs:
            nodeL = nodeList
            nodeList = []

        for node in nodeL:
            iok = 0
            for k, v in list(kwargs.items()):
                if node.getAttribute(str(k)) == str(v):
                    iok = 1
                else:
                    iok = 0
                    break
            if iok: nodeList.append(node)
#TRYME

        if not attrList and not kwargs:
            nodeList = nodeL

        return nodeList


    def _childNodeList(self, tag, *attrList, **kwargs):
        """
        Return a list of first child Element node from the explored XMLElement node.
        """
        nodeList = self._nodeList(tag, *attrList, **kwargs)

        childNodeList = []
        if self.el.hasChildNodes():
            for node in self.el.childNodes:
                if node.nodeType == Node.ELEMENT_NODE:
                    if node.nodeName == tag and node in nodeList:
                        childNodeList.append(node)

        return childNodeList


    def xmlAddChild(self, tag, *attrList, **kwargs):
        """
        Add a new XMLElement node as a child of the current
        XMLElement node (i.e. self), with attributes and value.
        """
        if self.ca: self.ca.modified()

        el = self.doc.createElement(tag)
        for k in attrList:
            el.setAttribute(k, "")
        for k, v in list(kwargs.items()):
            el.setAttribute(k, _encode(str(v)))

        nn = None
        for n in self.el.childNodes:
            if n.nodeType == self.doc.ELEMENT_NODE:
                if sorted([n.nodeName, tag]) != [n.nodeName, tag]:
                    nn = n
                    break
                if tag == "variable" and n.nodeName == "variable":
                    name1 = n.getAttributeNode("name").value
                    name2 = el.getAttributeNode("name").value
                    if sorted([name1, name2]) != [name1, name2]:
                        nn = n
                        break
                if tag == "property" and n.nodeName == "property":
                    name1 = n.getAttributeNode("name").value
                    name2 = el.getAttributeNode("name").value
                    if sorted([name1, name2]) != [name1, name2]:
                        nn = n
                        break

        log.debug("xmlAddChild-> %s %s" % (tag, self.__xmlLog()))

        return self._inst(self.el.insertBefore(el, nn))


    def xmlSetTextNode(self, newTextNode):
        """
        Replace old text value of a TEXT_NODE by the new one.
        If the elementNode 'node' has no TEXT_NODE as childNodes,
        it will be created.
        """
        if self.ca: self.ca.modified()

        if newTextNode == "" or newTextNode == None : return

        if type(newTextNode) != str: newTextNode = str(newTextNode)

        if self.el.hasChildNodes():
            for n in self.el.childNodes:
                if n.nodeType == Node.TEXT_NODE:
                    n.data = _encode(newTextNode)
        else:
            self._inst(
                self.el.appendChild(
                    self.doc.createTextNode(_encode(newTextNode))))

        log.debug("xmlSetTextNode-> %s" % self.__xmlLog())


    def xmlSetData(self, tag, textNode, *attrList, **kwargs):
        """
        Set the textNode in an elementNode, which is a single node.
        If the searched 'tag' doesn't exist, it is create
        and textNode is added as a child TEXT_NODE nodeType.
        Return a XMLElement list of the created Node.
        """
        # First we convert textNode in string, if necessary.
        # About the precision display read :
        # "B. Floating Point Arithmetic: Issues and Limitations
        #  http://www.python.org/doc/current/tut/node14.html"
        #
        if type(textNode) == float: textNode = str("%.12g" % (textNode))

        nodeList = self._childNodeList(tag, *attrList, **kwargs)
        elementList = []

        # Add a new ELEMENT_NODE and a new TEXT_NODE
        # or replace an existing TEXT_NODE
        #
        if not nodeList:
            child = self.xmlAddChild(tag, *attrList, **kwargs)
            child.xmlSetTextNode(textNode)
            elementList.append(child)
        else:
            for node in nodeList:
                child = self._inst(node)
                child.xmlSetTextNode(textNode)
                elementList.append(child)

        return elementList


    def xmlGetTextNode(self, sep=" "):
        """
        """
        rc = []
        if self.el.hasChildNodes():
            for node in self.el.childNodes:
                if node.nodeType == node.TEXT_NODE:
                    rc.append(node.data)
            return _encode(string.join(rc, sep))
        else:
            return None


    def xmlGetStringList(self, tag, *attrList, **kwargs):
        """
        Return a list of TEXT_NODE associed to the tagName elements
        from the explored elementNode.
        """
        stringList = []

        nodeList = self._nodeList(tag, *attrList, **kwargs)
        if nodeList:
            for node in nodeList:
                data = self._inst(node).xmlGetTextNode()
                if data:
                    stringList.append(data)

        return stringList


    def xmlGetChildStringList(self, tag, *attrList, **kwargs):
        """
        Return a list of TEXT_NODE associed to the tagName elements
        from the explored elementNode.
        """
        stringList = []

        nodeList = self._childNodeList(tag, *attrList, **kwargs)

        if nodeList:
            for node in nodeList:
                data = self._inst(node).xmlGetTextNode()
                if data:
                    stringList.append(data)

        return stringList


    def xmlGetIntList(self, tag, *attrList, **kwargs):
        """
        Return a list of integer insteed of a list of one string.
        """
        intList = []
        stringList = self.xmlGetStringList(tag, *attrList, **kwargs)

        for s in stringList:
            try:
                intList.append(int(s))
            except:
                pass

        return intList


    def xmlGetString(self, tag, *attrList, **kwargs):
        """
        Just verify that te returned list contains only one string variable.
        Return a string and not a list of one string.
        """
        stringList = self.xmlGetStringList(tag, *attrList, **kwargs)

        if stringList:
            if len(stringList) == 1:
                string = stringList[0]
            else:
                msg = "There is an error in with the use of the xmlGetString method. "\
                      "There is more than one occurence of the tagName: " + tag
                self._errorExit(msg)
        else:
            string = ""

        return string


    def xmlGetChildString(self, tag, *attrList, **kwargs):
        """
        Just verify that te returned list contains only one string variable.
        Return a string and not a list of one string.
        """
        stringList = self.xmlGetChildStringList(tag, *attrList, **kwargs)

        if stringList:
            if len(stringList) == 1:
                string = stringList[0]
            else:
                msg = "There is an error in with the use of the xmlGetChildString method. "\
                      "There is more than one occurence of the tagName: " + tag
                self._errorExit(msg)
        else:
            string = ""

        return string


    def xmlGetInt(self, tag, *attrList, **kwargs):
        """
        Just verify that te returned list contains only one string variable.
        Return an integer and not a list of one string.
        """
        stringList = self.xmlGetStringList(tag, *attrList, **kwargs)

        if stringList:
            if len(stringList) == 1:
                try:
                    integer = int(stringList[0])
                except:
                    integer = None
            else:
                msg = "There is an error in with the use of the xmlGetInt method. "\
                      "There is more than one occurence of the tagName: " + tag
                self._errorExit(msg)
        else:
            integer = None

        return integer


    def xmlGetDouble(self, tag, *attrList, **kwargs):
        """
        Just verify that the returned list contains only one string variable.
        Return a float and not a list of one string.
        """
        stringList = self.xmlGetStringList(tag, *attrList, **kwargs)

        if stringList:
            if len(stringList) == 1:
                try:
                    double = float(stringList[0])
                except:
                    double = None
            else:
                msg = "There is an error in with the use of the xmlGetDouble method. "\
                      "There is more than one occurence of the tagName: " + tag
                self._errorExit(msg)
        else:
            double = None

        return double


    def xmlGetChildDouble(self, tag, *attrList, **kwargs):
        """
        Just verify that te returned list contains only one string variable.
        Return a float and not a list of one string.
        """
        stringList = self.xmlGetChildStringList(tag, *attrList, **kwargs)

        if stringList:
            if len(stringList) == 1:
                try:
                    double = float(stringList[0])
                except:
                    double = None
            else:
                msg = "There is an error in with the use of the xmlGetChildDouble method. "\
                      "There is more than one occurence of the tagName: " + tag
                self._errorExit(msg)
        else:
            double = None

        return double


    def xmlAddComment(self, data):
        """
        Create a comment XMLElement node.
        """
        if self.ca: self.ca.modified()
        elt = self._inst( self.el.appendChild(self.doc.createComment(data)) )
        log.debug("xmlAddComment-> %s" % self.__xmlLog())
        return elt


    def xmlGetNodeList(self, tag, *attrList, **kwargs):
        """
        Return a list of XMLElement nodes from the explored
        XMLElement node (i.e. self).
        """
        return list(map(self._inst, self._nodeList(tag, *attrList, **kwargs)))


    def xmlGetNode(self, tag, *attrList, **kwargs):
        """
        Return a single XMLElement node from the explored elementNode.
        The returned element is an instance of the XMLElement class.
        """
        nodeList = self._nodeList(tag, *attrList, **kwargs)

        if len(nodeList) > 1:
            msg = "There is an error in with the use of the xmlGetNode method. "\
                  "There is more than one occurence of the tag: " + tag
            for n in nodeList: msg += "\n" + self._inst(n).__str__()
            self._errorExit(msg)
        elif len(nodeList) == 1:
            return self._inst(nodeList[0])
        else:
            return None


    def xmlGetChildNodeList(self, tag, *attrList, **kwargs):
        """
        Return a list of XMLElement nodes from the explored elementNode.
        Each element of the returned list is an instance of the XMLElement
        class.
        """
        return list(map(self._inst, self._childNodeList(tag, *attrList, **kwargs)))


    def xmlGetChildNode(self, tag, *attrList, **kwargs):
        """
        Return a single XMLElement node from the explored elementNode.
        The returned element is an instance of the XMLElement class.
        """
        nodeList = self._childNodeList(tag, *attrList, **kwargs)

        if len(nodeList) > 1:
            msg = "There is an error in with the use of the xmlGetChildNode method. "\
                  "There is more than one occurence of the tag: " + tag
            for n in nodeList: msg += "\n" + self._inst(n).__str__()
            self._errorExit(msg)
        elif len(nodeList) == 1:
            return self._inst(nodeList[0])
        else:
            return None


    def xmlInitNodeList(self, tag, *attrList, **kwargs):
        """
        Each element of the returned list is an instance
        of the XMLElement class.
        """
        nodeList = self._nodeList(tag, *attrList, **kwargs)

        if not nodeList:
            child = self.xmlAddChild(tag, *attrList, **kwargs)
            for k in attrList: child.el.setAttribute(k, "")
            for k, v in list(kwargs.items()): child.el.setAttribute(k, _encode(str(v)))
            nodeList.append(child)
        else:
            l = []
            for node in nodeList: l.append(self._inst(node))
            nodeList = l

        return nodeList


    def xmlInitChildNodeList(self, tag, *attrList, **kwargs):
        """
        Each element of the returned list is an instance
        of the XMLElement class.
        """
        nodeList = self._childNodeList(tag, *attrList, **kwargs)

        if not nodeList:
            child = self.xmlAddChild(tag, *attrList, **kwargs)
            for k in attrList: child.el.setAttribute(k, "")
            for k, v in list(kwargs.items()): child.el.setAttribute(k, _encode(str(v)))
            nodeList.append(child)
        else:
            l = []
            for node in nodeList: l.append(self._inst(node))
            nodeList = l

        return nodeList


    def xmlInitNode(self, tag, *attrList, **kwargs):
        """
        Return a single XMLElement node from the explored elementNode.
        If the tag does not exist, it will be created.
        The returned element is an instance of the XMLElement class.
        """
        nodeList = self._nodeList(tag, *attrList, **kwargs)

        if not nodeList:
            child = self.xmlAddChild(tag, *attrList, **kwargs)
            for k in attrList: child.el.setAttribute(k, "")
            for k, v in list(kwargs.items()): child.el.setAttribute(k, _encode(str(v)))
        else:
            if len(nodeList) > 1:
                msg = "There is an error in with the use of the xmlInitNode method. "\
                      "There is more than one occurence of the tag: " + tag
                for n in nodeList: msg += "\n" + self._inst(n).__str__()
                self._errorExit(msg)
            else:
                child = self._inst(nodeList[0])

        return child


    def xmlInitChildNode(self, tag, *attrList, **kwargs):
        """
        Return a single XMLElement child node from the explored elementNode.
        If the tag does not exist, it will be created.
        The returned element is an instance of the XMLElement class.
        """
        nodeList = self._childNodeList(tag, *attrList, **kwargs)

        if not nodeList:
            child = self.xmlAddChild(tag, *attrList, **kwargs)
            for k in attrList: child.el.setAttribute(k, "")
            for k, v in list(kwargs.items()): child.el.setAttribute(k, _encode(str(v)))
        else:
            if len(nodeList) > 1:
                msg = "There is an error in with the use of the xmlInitChildNode method. "\
                      "There is more than one occurence of the tag: " + tag
                for n in nodeList: msg += "\n" + self._inst(n).__str__()
                self._errorExit(msg)
            else:
                child = self._inst(nodeList[0])

        return child


    def xmlChildsCopy(self, oldNode, deep=1000):
        """
        Copy all childsNode of oldNode to the node newNode.
        'deep' is the childs and little-childs level of the copy.
        """
        if self.ca: self.ca.modified()

        if oldNode.el.hasChildNodes():
            for n in oldNode.el.childNodes:
                self._inst(self.el.appendChild(n.cloneNode(deep)))

        log.debug("xmlChildsCopy-> %s" % self.__xmlLog())


    def xmlRemoveNode(self):
        """
        Destroy a single node.
        """
        if self.ca: self.ca.modified()
        oldChild = self.el.parentNode.removeChild(self.el)
        oldChild.unlink()


    def xmlRemoveChild(self, tag, *attrList, **kwargs):
        """
        Destroy the nodeList found with 'tag' and
        'attrList'/'kwargs' if they exist.
        """
        for node in self._nodeList(tag, *attrList, **kwargs):
            self._inst(node).xmlRemoveNode()

        log.debug("xmlRemoveChild-> %s %s" % (tag, self.__xmlLog()))


    def xmlNormalizeWhitespace(self, text):
        """
        return a string without redundant whitespace.
        """
        # This function is important even if it is single line.
        # XML treats whitespace very flexibly; you can
        # include extra spaces or newlines wherever you like. This means that
        # you must normalize the whitespace before comparing attribute values or
        # element content; otherwise the comparison might produce a wrong
        # result due to the content of two elements having different amounts of
        # whitespace.
        return string.join(text.split(), ' ')


##class _Document(Document):
##    """
##    """
##    def writexml(self, writer, indent="", addindent="", newl=""):
##        """
##        """
##        writer.write('<?xml version="2.0" encoding="%s" ?>\n' % enc)
##        for node in self.childNodes:
##            node.writexml(writer, indent, addindent, newl)


class XMLDocument(XMLElement):
    """
    """
    def __init__(self, case=None, tag=None, *attrList, **kwargs):
        """
        """
##        self.doc  = _Document()
        self.doc  = Document()
        self.case = case

        XMLElement.__init__(self, self.doc, self.doc, self.case)

        if tag:
            self.el = self.xmlAddChild(tag, *attrList, **kwargs).el


    def root(self):
        """
        This function return the only one root element of the document
        (higher level of ELEMENT_NODE after the <?xml version="2.0" ?> markup).
        """
        return self._inst(self.doc.documentElement)


    def toString(self):
        """
        Return the XMLDocument to a byte string (without \n and \t).
        Unicode characters are encoded.
        """
        return self.el.toxml(enc)


    def toUnicodeString(self):
        """
        Return the XMLDocument node to a byte string (without \n and \t).
        Unicode string are decoded if it's possible by the standard output,
        if not unicode characters are replaced by '?' character.
        Warning: do not use this method for comparison purpose!
        """
        unicode_obj = self.el.toxml()
        try:
            return unicode_obj.encode("iso-8859-1",'replace')
        except:
            return unicode_obj.encode(sys.stdout.encoding,'replace')


    def toPrettyString(self):
        """
        Return the XMLDocument to a byte string with \n and \t.
        Unicode characters are encoded.
        """
        return self.doc.toprettyxml(encoding = enc)


    def toPrettyUnicodeString(self):
        """
        Return the XMLDocument node to a byte string with \n and \t.
        Unicode string are decoded if it's possible by the standard output,
        if not unicode characters are replaced by '?' character.
        Warning: the returned XMLDocument do not show the encoding in the
        header, because it is already encoded!
        Warning: do not use this method for comparison purpose!
        """
        unicode_obj = self.el.toprettyxml()
        try:
            return unicode_obj.encode("iso-8859-1",'replace')
        except:
            return unicode_obj.encode(sys.stdout.encoding,'replace')


    def __str__(self):
        """
        Print the XMLDocument node with \n and \t.
        Unicode string are decoded if it's possible by the standard output,
        if not unicode characters are replaced by '?' character.
        Warning: the returned XMLDocument do not show the encoding in the
        header, because it is already encoded!
        Warning: do not use this method for comparison purpose!
        """
        return self.toPrettyUnicodeString()


    def parse(self, d):
        """
        return a xml doc from a file
        """
        self.doc = self.el = parse(d)
        return self


    def parseString(self, d):
        """
        return a xml doc from a string
        """
        self.doc = self.el = parseString(_encode(d))
        return self


    def xmlCleanAllBlank(self, node):
        """
        Clean a previous XMLElement file. The purpose of this method
        is to delete all TEXT_NODE which are "\n" or "\t".
        It is a recursive method.
        """
        if isinstance(node, XMLElement):
            node = node.el

        if 'formula' not in node.tagName:
            for n in node.childNodes:
                if n.nodeType == Node.TEXT_NODE:
                    n.data = self.xmlNormalizeWhitespace(n.data)
        else:
            for n in node.childNodes:
                if n.nodeType == Node.TEXT_NODE:
                    while n.data[0] in (" ", "\n", "\t"):
                        n.data = n.data[1:]
                    while n.data[-1] in (" ", "\n", "\t"):
                        n.data = n.data[:-1]

        node.normalize()

        for n in node.childNodes:
            if n.nodeType == Node.TEXT_NODE:
                if n.data == "":
                    old_child = node.removeChild(n)
                    old_child.unlink()

        for n in node.childNodes:
            if n.nodeType == Node.ELEMENT_NODE:
                if n.hasChildNodes(): self.xmlCleanAllBlank(n)


    def xmlCleanHightLevelBlank(self, node):
        """
        This method deletes TEXT_NODE which are "\n" or "\t" in the
        hight level of the ELEMENT_NODE nodes. It is a recursive method.
        """
        if isinstance(node, XMLElement):
            node = node.el

        elementNode = 0
        for n in node.childNodes:
            if n.nodeType == Node.ELEMENT_NODE:
                elementNode = 1
                if n.hasChildNodes():
                    self.xmlCleanHightLevelBlank(n)

        if 'formula' not in node.tagName:
            for n in node.childNodes:
                if n.nodeType == Node.TEXT_NODE and not elementNode:
                    self.xmlCleanAllBlank(n.parentNode)
        else:
            for n in node.childNodes:
                if n.nodeType == Node.TEXT_NODE:
                    while n.data[0] in (" ", "\n", "\t"):
                        n.data = n.data[1:]
                    while n.data[-1] in (" ", "\n", "\t"):
                        n.data = n.data[:-1]

#-------------------------------------------------------------------------------
# XML utility functions
#-------------------------------------------------------------------------------

class Case(Dico, XMLDocument, QObject):
    def __init__(self, package=None, file_name=""):
        """
        Instantiate a new dico and a new xml doc
        """
        Dico.__init__(self)
        XMLDocument.__init__(self, case=self)
        QObject.__init__(self)

        self['package'] = package
        rootNode = '<' + self['package'].code_name +'_GUI study="" case="" version="2.0"/>'

        if file_name:
            self.parse(file_name)
            self['new'] = "no"
            self['saved'] = "yes"
        else:
            self.parseString(rootNode)
            self['new'] = "yes"
            self['saved'] = "yes"

        self.record_func_prev = None
        self.record_argument_prev = None
        self.record_local = False
        self.record_global = True
        self.xml_prev = ""


    def xmlRootNode(self):
        """
        This function return the only one root element of the document
        (higher level of ELEMENT_NODE).
        """
        return self.doc.documentElement


    def modified(self):
        """
        Return if the xml doc is modified.
        """
        self['saved'] = "no"


    def isModified(self):
        """
        Return True if the xml doc is modified.
        """
        return self['saved'] == "no"


    def __del__(self):
        """
        What to do when the instance of Case is deleted.
        """
        if hasattr(self, 'data'):
            delattr(self, 'data')

        if hasattr(self, 'doc'):
            self.doc.unlink()
            delattr(self, 'doc')


    def __str__(self):
        """
        Print on the current terminal the contents of the case.
        """
        self.printDico()
        return self.toPrettyUnicodeString()


    def xmlSaveDocument(self):
        """
        This method writes the associated xml file.
        See saveCase and saveCaseAs methods in the Main module.
        """
        try:
            d = XMLDocument().parseString(self.toPrettyString())
            d.xmlCleanHightLevelBlank(d.root())
            file = open(self['xmlfile'], 'w')
            file.write(d.toString())
            file.close()
            self['new'] = "no"
            self['saved'] = "yes"
            d.doc.unlink()
        except IOError:
            msg = "Error: unable to save the XML document file." ,
            "(XMLengine module, Case class, xmlSaveDocument method)"
            print(msg)


    def undoStop(self):
        self.record_local = True


    def undoStart(self):
        self.record_local = False


    def undoStopGlobal(self):
        self.record_global = False


    def undoStartGlobal(self):
        self.record_global = True


    def undoGlobal(self, f, c):
        if self['current_page'] != '' and self.record_local == False and self.record_global == True:
            if self.xml_prev != self.toString() or self.xml_prev == "":
                # control if function have same arguments
                # last argument is value
                same = True
                if self.record_argument_prev == None:
                    same = False
                elif (len(c) == len(self.record_argument_prev) and len(c) >= 2):
                    for i in range(0, len(c)-1):
                        if c[i] != self.record_argument_prev[i]:
                            same = False

                if same:
                    pass
                else:
                    self['undo'].append([self['current_page'], self.toString(), self['current_index'], self['current_tab']])
                    self.xml_prev = self.toString()
                    self.record_func_prev = None
                    self.record_argument_prev = c
                    self.emit(SIGNAL("undo"))


    def undo(self, f, c):
        if self['current_page'] != '' and self.record_local == False and self.record_global == True:
            if self.xml_prev != self.toString():
                # control if function have same arguments
                # last argument is value
                same = True
                if self.record_argument_prev == None:
                    same = False
                elif (len(c) == len(self.record_argument_prev) and len(c) >= 2):
                    for i in range(0, len(c)-1):
                        if c[i] != self.record_argument_prev[i]:
                            same = False

                if self.record_func_prev == f and same:
                    pass
                else:
                    self.record_func_prev = f
                    self.record_argument_prev = c
                    self['undo'].append([self['current_page'], self.toString(), self['current_index'], self['current_tab']])
                    self.xml_prev = self.toString()
                    self.emit(SIGNAL("undo"))


#-------------------------------------------------------------------------------
# XMLengine test case
#-------------------------------------------------------------------------------


class XMLengineTestCase(unittest.TestCase):
    def setUp(self):
        """This method is executed before all "check" methods."""
        self.doc = XMLDocument()


    def tearDown(self):
        """This method is executed after all "check" methods."""
        self.doc.doc.unlink()


    def xmlNewFile(self):
        """Private method to return a xml document."""
        return \
        u'<root><first/><market><cucumber/><fruits color="red"/></market></root>'


    def xmlNodeFromString(self, string):
        """Private method to return a xml node from string"""
        return self.doc.parseString(string).root()


    def checkXMLDocumentInstantiation(self):
        """Check whether the Case class could be instantiated."""
        xmldoc = None
        tag    = None
        xmldoc = XMLDocument(tag=tag)

        assert xmldoc, 'Could not instantiate XMLDocument'


    def checkXmlAddChild(self):
        """Check whether a node child could be added."""
        node = self.doc.xmlAddChild("table", name="test")
        node.xmlAddChild("field", "label", name="info", type="text")
        truc = node.toString()
        doc = '<table name="test">'\
                '<field label="" name="info" type="text"/>'\
              '</table>'

        assert doc == truc, 'Could not use the xmlAddChild method'


    def checkNodeList(self):
        """Check whether a node could be found if it does exist."""
        xmldoc = self.doc.parseString(self.xmlNewFile())
        node = '<fruits color="red"/>'

        nodeList = xmldoc._nodeList('fruits')
        truc = nodeList[0].toxml()
        assert node == truc, 'Could not use the _nodeList method'

        nodeList = xmldoc._nodeList('fruits', 'color')
        truc = nodeList[0].toxml()
        assert node == truc, 'Could not use the _nodeList method'

        nodeList = xmldoc._nodeList('fruits', color="red")
        truc = nodeList[0].toxml()
        assert node == truc, 'Could not use the _nodeList method'


    def checkChildNodeList(self):
        """Check whether a child node could be found if it does exist."""
        xmldoc = self.doc.parseString(self.xmlNewFile())
        n = self.doc._inst(xmldoc.doc.firstChild.childNodes[1])
        node = '<fruits color="red"/>'

        nodeList = n._childNodeList('fruits')
        truc = nodeList[0].toxml()
        assert node == truc, 'Could not use the _childNodeList method'

        nodeList = n._childNodeList('fruits', 'color')
        truc = nodeList[0].toxml()
        assert node == truc, 'Could not use the _childNodeList method'

        nodeList = n._childNodeList('fruits', color="red")
        truc = nodeList[0].toxml()
        assert node == truc, 'Could not use the _childNodeList method'

        nodeList = xmldoc._childNodeList('fruits', color="red")
        self.failUnless(nodeList==[], 'Could not use the _childNodeList method')


    def checkXmlInitNodeList(self):
        """Check whether a node child list could be get."""
        nList1 = self.doc.xmlInitNodeList("table", name="test")
        nList2 = nList1[0].xmlInitNodeList("field", "label", name="info", type="text")
        truc = nList1[0].toString()
        doc = '<table name="test">'\
                '<field label="" name="info" type="text"/>'\
              '</table>'

        assert doc == truc, 'Could not use the xmlInitNodeList method'

        xmldoc = self.doc.parseString(self.xmlNewFile())
        node = '<fruits color="red"/>'

        nodeList = xmldoc.xmlInitNodeList('fruits')
        truc = nodeList[0].toString()
        assert node == truc, 'Could not use the xmlInitNodeList method'

        nodeList = xmldoc.xmlInitNodeList('fruits', 'color')
        truc = nodeList[0].toString()
        assert node == truc, 'Could not use the xmlInitNodeList method'

        nodeList = xmldoc.xmlInitNodeList('fruits', color="red")
        truc = nodeList[0].toString()
        assert node == truc, 'Could not use the xmlinitNodeList method'


    def checkXmlInitNode(self):
        """Check whether a node child could be get."""
        n1 = self.doc.xmlInitNode("table", name="test")
        n2 = n1.xmlInitNode("field", "label", name="info", type="text")
        truc = n1.toString()
        doc = '<table name="test">'\
                '<field label="" name="info" type="text"/>'\
              '</table>'

        assert doc == truc, 'Could not use the xmlInitNodeList method'

        xmldoc = self.doc.parseString(self.xmlNewFile())
        node = '<fruits color="red"/>'

        truc = xmldoc.xmlInitNode('fruits').toString()
        assert node == truc, 'Could not use the xmlInitNode method'

        truc = xmldoc.xmlInitNode('fruits', 'color').toString()
        assert node == truc, 'Could not use the xmlInitNode method'

        truc = xmldoc.xmlInitNode('fruits', color="red").toString()
        assert node == truc, 'Could not use the xmlInitNode method'


    def checkXmlInitChildNodeList(self):
        """Check whether a child node list could be found if it does exist."""
        xmldoc = self.doc.parseString(self.xmlNewFile())
        thermo = self.doc._inst(xmldoc.doc.firstChild.childNodes[1])
        truc = '<market><cucumber/><fruits color="red"/></market>'
        assert thermo.toString() == truc, 'Could not use the firstChild.childNodes method'

        node = '<fruits color="red"/>'

        nodeList = thermo.xmlInitChildNodeList('fruits')
        truc = nodeList[0].toString()
        assert node == truc, 'Could not use the xmlInitChildNodeList method'

        nodeList = thermo.xmlInitChildNodeList('fruits', 'color')
        truc = nodeList[0].toString()
        assert node == truc, 'Could not use the xmlInitChildNodeList method'

        nodeList = thermo.xmlInitChildNodeList('fruits', color="red")
        truc = nodeList[0].toString()
        assert node == truc, 'Could not use the xmlInitChildNodeList method'


    def checkXmlInitChildNode(self):
        """Check whether a node child could be get."""
        n1 = self.doc.xmlInitChildNode("table", name="test")
        n2 = n1.xmlInitChildNode("field", "label", name="info", type="text")
        truc = n1.toString()
        doc = '<table name="test">'\
                '<field label="" name="info" type="text"/>'\
              '</table>'

        assert doc == truc, 'Could not use the xmlInitNodeList method'

        xmldoc = self.doc.parseString(self.xmlNewFile())
        thermo = self.doc._inst(xmldoc.doc.firstChild.childNodes[1])
        node = '<fruits color="red"/>'

        truc = thermo.xmlInitChildNode('fruits').toString()
        assert node == truc, 'Could not use the xmlInitChildNode method'

        truc = thermo.xmlInitChildNode('fruits', 'color').toString()
        assert node == truc, 'Could not use the xmlInitChildNode method'

        truc = thermo.xmlInitChildNode('fruits', color="red").toString()
        assert node == truc, 'Could not use the xmlInitChildNode method'


    def checkXmlGetNodeList(self):
        """Check whether a node list could be found if it does exist."""
        xmldoc = self.doc.parseString(self.xmlNewFile())
        node = '<fruits color="red"/>'

        nodeList = xmldoc.xmlGetNodeList('fruits')
        truc = nodeList[0].toString()
        assert node == truc, 'Could not use the xmlGetNodeList method'

        nodeList = xmldoc.xmlGetNodeList('fruits', 'color')
        truc = nodeList[0].toString()
        assert node == truc, 'Could not use the xmlGetNodeList method'

        nodeList = xmldoc.xmlGetNodeList('fruits', color="red")
        truc = nodeList[0].toString()
        assert node == truc, 'Could not use the xmlGetNodeList method'

        nodeList = xmldoc.xmlGetNodeList('fruits', color="red")
        self.failIf(nodeList==[], 'Could not use the xmlGetNodeList method')


    def checkXmlGetChildNodeList(self):
        """Check whether a child node list could be found if it does exist."""
        xmldoc = self.doc.parseString(self.xmlNewFile())
        thermo = self.doc._inst(xmldoc.doc.firstChild.childNodes[1])
        node = '<fruits color="red"/>'

        nodeList = thermo.xmlGetChildNodeList('fruits')
        truc = nodeList[0].toString()
        assert node == truc, 'Could not use the xmlGetChildNodeList method'

        nodeList = thermo.xmlGetChildNodeList('fruits', 'color')
        truc = nodeList[0].toString()
        assert node == truc, 'Could not use the xmlGetChildNodeList method'

        nodeList = thermo.xmlGetChildNodeList('fruits', color="red")
        truc = nodeList[0].toString()
        assert node == truc, 'Could not use the xmlGetChildNodeList method'

        nodeList = xmldoc.xmlGetChildNodeList('fruits', color="red")
        self.failUnless(nodeList==[], 'Could not use the xmlGetChildNodeList method')


    def checkXmlGetNode(self):
        """Check whether a child node could be found if it does exist."""
        xmldoc = self.doc.parseString(self.xmlNewFile())
        node = '<fruits color="red"/>'

        truc = xmldoc.xmlGetNode('fruits').toString()
        assert node == truc, 'Could not use the xmlGetNode method'

        truc = xmldoc.xmlGetNode('fruits', 'color').toString()
        assert node == truc, 'Could not use the xmlGetNode method'

        truc = xmldoc.xmlGetNode('fruits', color="red").toString()
        assert node == truc, 'Could not use the xmlGetNode method'

        empty = xmldoc.xmlGetNode('fruits', color="red")
        assert empty, 'Could not use the xmlGetNode method'


    def checkXmlGetChildNode(self):
        """Check whether a child node could be found if it does exist."""
        xmldoc = self.doc.parseString(self.xmlNewFile())
        n = self.doc._inst(xmldoc.doc.firstChild.childNodes[1])
        node = '<fruits color="red"/>'

        truc = n.xmlGetChildNode('fruits').toString()
        assert node == truc, 'Could not use the xmlGetChildNode method'

        truc = n.xmlGetChildNode('fruits', 'color').toString()
        assert node == truc, 'Could not use the xmlGetChildNode method'

        truc = n.xmlGetChildNode('fruits', color="red").toString()
        assert node == truc, 'Could not use the xmlGetChildNode method'

        empty = xmldoc.xmlGetChildNode('fruits', color="red")
        self.failUnless(empty==None, 'Could not use the xmlGetChildNode method')


    def checkXMLDocumentUnicodeParseString(self):
        """Check whether a XMLDocument with unicode string could be created."""
        d = XMLDocument()
        d.parseString(u'<français a="àùè">tâché</français>')

        t = u'<?xml version="2.0" encoding="utf-8"?>\n' \
            u'<français a="àùè">tâché</français>'
        t = t.encode(enc)
        assert d.toString() == t, 'Could not use the parseString method with utf-8 encoding'

        t = u'<?xml version="2.0" encoding="utf-8"?>\n' \
            u'<français a="àùè">\n\ttâché\n</français>\n'
        t = t.encode(enc)
        assert d.toPrettyString() == t, 'Could not use the parseString method with utf-8 encoding'

        t = self.xmlNodeFromString(u'<français a="àùè">tâché</français>')
        assert d.root() == t, 'Could not use the parseString method with utf-8 encoding'


    def checkXmlNodeFromString(self):
        """"Check whether two XML nodes could be compared."""
        print('\n')
        n1 = self.xmlNodeFromString(u'<fruits taste="ok" color="red"><a>toto</a><c a="2é"/></fruits>')
        n2 = XMLDocument().parseString(u'<fruits color="red" taste="ok"><c a="2é"/><a>toto</a></fruits>').root()
        assert n1 == n2, 'This two node are not identical'

        n3 = self.xmlNodeFromString(u'<fruits><b/><a>123.0</a></fruits>')
        n4 = XMLDocument().parseString(u'<fruits><a>123</a><b/></fruits>').root()
        assert n3 == n4, 'This two node are not identical'

        d1 = '<fruits><apple from="W" name="P"/><apple from="P"/></fruits>'
        d2 = '<fruits><apple from="P"/><apple from="W" name="P"/></fruits>'
        n5 = self.xmlNodeFromString(d1)
        n6 = XMLDocument().parseString(d2).root()
        assert n5 == n6, 'This two node are not identical'

        d1 = '<velocity_pressure>'\
                 '<variable label="U" name="velocity_U"/>'\
                 '<variable label="V" name="velocity_V"/>'\
                 '<variable label="W" name="velocity_W"/>'\
                 '<variable label="P" name="pressure"/>'\
              '</velocity_pressure>'
        d2 = '<velocity_pressure>'\
                 '<variable label="P" name="pressure"/>'\
                 '<variable label="U" name="velocity_U"/>'\
                 '<variable label="V" name="velocity_V"/>'\
                 '<variable label="W" name="velocity_W"/>'\
              '</velocity_pressure>'
        n5 = self.xmlNodeFromString(d1)
        n6 = XMLDocument().parseString(d2).root()
        assert n5 == n6, 'This two node are not identical'

        d1 = '<turbulence model="Rij-epsilon">'\
                '<property label="turb. vi" name="turbulent_viscosity"/>'\
                '<variable label="R11" name="component_R11"/>'\
            '</turbulence>'
        d2 = '<turbulence model="Rij-epsilon">'\
                '<variable label="R11" name="component_R11"/>'\
                '<property label="turb. vi" name="turbulent_viscosity"/>'\
            '</turbulence>'
        n5 = self.xmlNodeFromString(d1)
        n6 = XMLDocument().parseString(d2).root()
        assert n5 == n6, 'This two node are not identical'

    def checkCaseInstantiation(self):
        """Check whether the Case class could be instantiated."""
        case = None
        case = Case()
        assert case, 'Could not instantiate Case'


    def checkCaseParseString(self):
        """Check whether a Case could be created."""
        case = Case()
        assert case.root() == self.xmlNodeFromString(rootNode), \
               'Could not use the parseString method'


    def checkXmlSaveDocument(self):
        """Check whether a Case could be save on the file system"""
        case = Case()
        case.parseString(u'<fruits color="red" taste="ok"><c a="2é">to</c></fruits>')
        case['xmlfile'] = os.path.dirname(os.getcwd()) + "/ToTo"
        if os.path.isfile(case['xmlfile']):
            os.remove(case['xmlfile'])
        case.xmlSaveDocument()

        if not os.path.isfile(case['xmlfile']):
            assert False, \
            'Could not save the file ' + case['xmlfile']

        d= case.parse(case['xmlfile'])
        os.remove(case['xmlfile'])
        d.xmlCleanAllBlank(d.root())
        assert case.root() == d.root(), \
               'Could not use the xmlSaveDocument method'


##    def checkFailUnless(self):
##        """Test"""
##        self.failUnless(1==1, "One should be one.")
##
##
##    def checkFailIf(self):
##        """Test"""
##        self.failIf(1==2,"I don't one to be one, I want it to be two.")


def suite():
    """unittest function"""
    testSuite = unittest.makeSuite(XMLengineTestCase, "check")
    return testSuite


def runTest():
    """unittest function"""
    print("XMLengineTestCase to be completed...")
    runner = unittest.TextTestRunner()
    runner.run(suite())

#-------------------------------------------------------------------------------
# End of XMLengine
#-------------------------------------------------------------------------------

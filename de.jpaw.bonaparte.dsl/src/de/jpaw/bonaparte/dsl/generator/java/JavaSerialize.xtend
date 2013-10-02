 /*
  * Copyright 2012 Michael Bischoff
  *
  * Licensed under the Apache License, Version 2.0 (the "License");
  * you may not use this file except in compliance with the License.
  * You may obtain a copy of the License at
  *
  *   http://www.apache.org/licenses/LICENSE-2.0
  *
  * Unless required by applicable law or agreed to in writing, software
  * distributed under the License is distributed on an "AS IS" BASIS,
  * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  * See the License for the specific language governing permissions and
  * limitations under the License.
  */

package de.jpaw.bonaparte.dsl.generator.java

import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition

import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.ElementaryDataType
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import static extension de.jpaw.bonaparte.dsl.generator.DataTypeExtensions2.*
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.dsl.generator.DataCategory

class JavaSerialize {

    def private static makeWrite(FieldDefinition i, String indexedName, ElementaryDataType e, DataTypeExtension ref) {
        if (ref.isPrimitive || ref.category == DataCategory.OBJECT)
            '''w.addField(«indexedName»);'''     // no di attribute
        else if (ref.isWrapper) {  // boxed types: separate call for Null, else unbox!
            '''if («indexedName» == null) w.writeNull(meta$$«i.name»); else w.addField(«indexedName»);'''
        } else {
            '''w.addField(meta$$«i.name», «indexedName»);'''
        }
    }

    def private static makeWrite2(ClassDefinition d, FieldDefinition i, String index) '''
        «IF i.datatype.pointsToElementaryDataType»
            «makeWrite(i, index, resolveElem(i.datatype), DataTypeExtension::get(i.datatype))»
        «ELSEIF i.datatype.isEnum»
        	w.addField(meta$$«i.name»$token, «index» == null ? null : «IF i.datatype.enumMaxTokenLength >= 0»«index».getToken()«ELSE»Integer.valueOf(«index».ordinal())«ENDIF»);
        «ELSE»
            w.addField((BonaPortable)«index»);
        «ENDIF»
    '''

    def private static makeFoldedWrite2(ClassDefinition d, FieldDefinition i, String index) '''
        «IF i.datatype.pointsToElementaryDataType»
            «makeWrite(i, index, resolveElem(i.datatype), DataTypeExtension::get(i.datatype))»
        «ELSEIF i.datatype.isEnum»
        	w.addField(meta$$«i.name»$token, «index» == null ? null : «IF i.datatype.enumMaxTokenLength >= 0»«index».getToken()«ELSE»Integer.valueOf(«index».ordinal())«ENDIF»);
        «ELSE»
            if («index» == null) {
                w.writeNull(meta$$«i.name»);
            } else if (pfc.getComponent() == null) {
                w.addField((BonaPortable)«index»);             // full / recursive object output
            } else {
                // write a specific subcomponent
                «index».foldedOutput(w, pfc.getComponent());   // recurse specific field
            }
        «ENDIF»
    '''

    def public static writeSerialize(ClassDefinition d) '''
        /* serialize the object into a String. uses implicit toString() member functions of elementary data types */
        @Override
        public <E extends Exception> void serializeSub(MessageComposer<E> w) throws E {
            «IF d.extendsClass != null»
                // recursive call of superclass first
                super.serializeSub(w);
            «ENDIF»
            «FOR i:d.fields»
                «IF i.isAggregate»
                    if («i.name» == null) {
                        w.writeNullCollection(meta$$«i.name»);
                    } else {
                        «IF i.isArray != null»
                            w.startArray(«i.name».length, «i.isArray.maxcount», 0);
                            for (int _i = 0; _i < «i.name».length; ++_i)
                                «makeWrite2(d, i, indexedName(i))»
                            w.terminateArray();
                        «ELSEIF i.isList != null || i.isSet != null»
                            w.startArray(«i.name».size(), «i.loopMaxCount», 0);
                            for («JavaDataTypeNoName(i, true)» _i : «i.name»)
                                «makeWrite2(d, i, indexedName(i))»
                            w.terminateArray();
                        «ELSE»
                            w.startMap(«i.name».size(), «mapIndexID(i.isMap)»);
                            for (Map.Entry<«i.isMap.indexType»,«JavaDataTypeNoName(i, true)»> _i : «i.name».entrySet()) {
                                // write (key, value) tuples
                                «IF i.isMap.indexType == "String"»
                                    w.addField(StaticMeta.MAP_INDEX_META, _i.getKey());
                                «ELSE»
                                    w.addField(_i.getKey());
                                «ENDIF»
                                «makeWrite2(d, i, indexedName(i))»
                            }
                            w.terminateArray();
                        «ENDIF»
                    }
                «ELSE»
                    «makeWrite2(d, i, indexedName(i))»
                «ENDIF»
            «ENDFOR»
            w.writeSuperclassSeparator();
        }

    '''

    def public static writeFoldedSerialize(ClassDefinition d) '''
        /* serialize selected fields of the object. */
        @Override
        public <E extends Exception> void foldedOutput(MessageComposer<E> w, ParsedFoldingComponent pfc) throws E {
            String _n = pfc.getFieldname();
            «FOR i:d.fields»
                if (_n.equals("«i.name»")) {
                    «IF !i.isAggregate»
                        «makeFoldedWrite2(d, i, indexedName(i))»
                    «ELSE»
                        if («i.name» == null) {
                            w.writeNullCollection(meta$$«i.name»);
                        } else {
                            «IF i.isArray != null»
                                if (pfc.index < 0) {
                                    w.startArray(«i.name».length, «i.isArray.maxcount», 0);
                                    for (int _i = 0; _i < «i.name».length; ++_i) {
                                        «makeFoldedWrite2(d, i, indexedName(i))»
                                    }
                                    w.terminateArray();
                                } else {
                                    if (pfc.index < «i.name».length) {
                                        // output single element
                                        «makeFoldedWrite2(d, i, i.name + "[pfc.index]")»
                                    }
                                }
                            «ELSEIF i.isList != null»
                                if (pfc.index < 0) {
                                    w.startArray(«i.name».size(), «i.loopMaxCount», 0);
                                    for («JavaDataTypeNoName(i, true)» _i : «i.name») {
                                        «makeFoldedWrite2(d, i, indexedName(i))»
                                    }
                                    w.terminateArray();
                                } else {
                                    if (pfc.index < «i.name».size()) {
                                        // output single element
                                        «makeFoldedWrite2(d, i, i.name + ".get(pfc.index)")»
                                    }
                                }
                            «ELSEIF i.isSet != null»
                                w.startArray(«i.name».size(), «i.loopMaxCount», 0);
                                for («JavaDataTypeNoName(i, true)» _i : «i.name») {
                                    «makeFoldedWrite2(d, i, indexedName(i))»
                                }
                                w.terminateArray();
                            «ELSE»
                                «IF i.isMap.indexType == "String"»
                                    if (pfc.alphaIndex == null) {
                                «ELSE»
                                    if (pfc.index < 0) {
                                «ENDIF»
                                    w.startMap(«i.name».size(), «mapIndexID(i.isMap)»);
                                    for (Map.Entry<«i.isMap.indexType»,«JavaDataTypeNoName(i, true)»> _i : «i.name».entrySet()) {
                                        // write (key, value) tuples
                                        «IF i.isMap.indexType == "String"»
                                            w.addField(StaticMeta.MAP_INDEX_META, _i.getKey());
                                        «ELSE»
                                            w.addField(_i.getKey());
                                        «ENDIF»
                                        «makeFoldedWrite2(d, i, indexedName(i))»
                                    }
                                    w.terminateArray();
                                } else {
                                    «IF i.isMap.indexType == "String"»
                                        «makeFoldedWrite2(d, i, i.name + ".get(pfc.alphaIndex)")»
                                    «ELSEIF i.isMap.indexType == "Integer"»
                                        «makeFoldedWrite2(d, i, i.name + ".get(Integer.valueOf(pfc.index))")»
                                    «ELSE»
                                        «makeFoldedWrite2(d, i, i.name + ".get(Long.valueOf((long)pfc.index))")»
                                    «ENDIF»
                                }
                            «ENDIF»
                        }
                    «ENDIF»
                    return;
                }
            «ENDFOR»
            // not found
            «IF d.extendsClass != null»
                super.foldedOutput(w, pfc);
            «ENDIF»
        }

   '''
}

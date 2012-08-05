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
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension

class JavaSerialize {
   
    def private static makeWrite(String indexedName, ElementaryDataType e, DataTypeExtension ref) {
        val String grammarName = e.name.toLowerCase;
        if (grammarName.equals("unicode") && ref.effectiveAllowCtrls)  // special treatment if escaped characters must be checked for
            '''w.addEscapedString(«indexedName», «e.length»);'''
        else if (ref.javaType.equals("String") || grammarName.equals("raw") || grammarName.equals("timestamp"))
            '''w.addField(«indexedName», «e.length»);'''
        else if (grammarName.equals("decimal"))
            '''w.addField(«indexedName», «e.length», «e.decimals», «ref.effectiveSigned»);'''
        else if (grammarName.equals("number"))
            '''w.addField(«indexedName», «e.length», «ref.effectiveSigned»);'''
        else if (grammarName.equals("day"))
            '''w.addField(«indexedName», -1);'''
        else if (grammarName.equals("enum"))       // enums to be written as their ordinals
            '''w.addField(«indexedName».ordinal());'''
        else // primitive or boxed type
            '''w.addField(«indexedName»);'''
    }

    def private static makeWrite2(ClassDefinition d, FieldDefinition i, String index) '''
        «IF resolveElem(i.datatype) != null»
            «makeWrite(i.name + index, resolveElem(i.datatype), DataTypeExtension::get(i.datatype))»
        «ELSE»
            w.addField((BonaPortable)«i.name»«index»);
        «ENDIF»
    '''
    
    def public static writeSerialize(ClassDefinition d) '''
            /* serialize the object into a String. uses implicit toString() member functions of elementary data types */
            @Override
            public void serialiseSub(MessageComposer w) {
                «IF d.extendsClass != null»
                    // recursive call of superclass first
                    super.serialiseSub(w);
                    w.writeSuperclassSeparator();
                «ENDIF»
                «FOR i:d.fields»
                    «IF i.isArray != null»
                        if («i.name» == null) {
                            w.writeNull();
                        } else {
                            w.startArray(«i.name».length, «i.isArray.maxcount»);
                            for (int i = 0; i < «i.name».length; ++i)
                                «makeWrite2(d, i, "[i]")»
                            w.terminateArray();
                        }
                    «ELSE»
                        «makeWrite2(d, i, "")»
                    «ENDIF»
                «ENDFOR»
            }


            /* serialize the object into a String. uses implicit toString() member functions of elementary data types */
            // this method is not needed any more because it is performed in the MessageComposer object
            @Override
            public void serialise(MessageComposer w) {
                // start a new object
                w.startObject(MEDIUM_CLASS_NAME, REVISION);
                // do all fields
                serialiseSub(w);
                // terminate the object
                w.terminateObject();
            }
   '''    
}
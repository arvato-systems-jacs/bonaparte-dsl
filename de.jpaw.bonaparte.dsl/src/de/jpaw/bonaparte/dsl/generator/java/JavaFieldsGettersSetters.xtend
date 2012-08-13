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
import de.jpaw.bonaparte.dsl.bonScript.XVisibility
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.dsl.generator.Util

class JavaFieldsGettersSetters {

    def private static makeVisbility(FieldDefinition i) {
        var XVisibility fieldScope = DataTypeExtension::get(i.datatype).visibility
        if (fieldScope == null || fieldScope == XVisibility::DEFAULT)
            ""
        else
            fieldScope.toString() + " " 
    } 
    
    // TODO: Setters might need to check string max length, and also clone for GregorianCalendar and byte arrays?
    def public static writeFields(ClassDefinition d) '''
            // fields as defined in DSL
            «FOR i:d.fields»
                «makeVisbility(i)»«JavaDataTypeNoName(i, false)» «i.name»;
            «ENDFOR»
            
            // auto-generated getters and setters 
            «FOR i:d.fields»
                public «JavaDataTypeNoName(i, false)» get«Util::capInitial(i.name)»() {
                    return «i.name»;
                }
                public void set«Util::capInitial(i.name)»(«JavaDataTypeNoName(i, false)» «i.name») {
                    this.«i.name» = «i.name»;
                }
            «ENDFOR»
    '''
}
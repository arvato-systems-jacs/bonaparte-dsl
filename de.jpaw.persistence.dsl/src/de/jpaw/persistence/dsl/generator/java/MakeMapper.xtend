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

package de.jpaw.persistence.dsl.generator.java

import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.persistence.dsl.bDDL.EmbeddableUse
import java.util.List

import static de.jpaw.bonaparte.dsl.generator.java.JavaPackages.*
import static de.jpaw.persistence.dsl.generator.YUtil.*
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*

class MakeMapper {
	def private static simpleGetter(String variable, ClassDefinition pojo, List<FieldDefinition> fieldsToIgnore) '''
        «FOR i:pojo.fields»
            «IF !hasProperty(i.properties, PROP_NOJAVA) && !hasProperty(i.properties, PROP_REF) &&!inList(fieldsToIgnore, i)»
                «variable».set«i.name.toFirstUpper»(get«i.name.toFirstUpper»());
            «ENDIF»
        «ENDFOR»
	'''
    def private static CharSequence recurseDataGetter(ClassDefinition cl, List<FieldDefinition> fieldsToIgnore, List<EmbeddableUse> embeddables) '''
    	«IF cl.extendsClass?.classRef != null»
    		«recurseDataGetter(cl.extendsClass?.classRef, fieldsToIgnore, embeddables)»
    	«ENDIF»
    	«simpleGetter("_r", cl, fieldsToIgnore)»
    '''
	def private static simpleSetter(String variable, ClassDefinition pojo, List<FieldDefinition> fieldsToIgnore) '''
        «FOR i:pojo.fields»
            «IF !hasProperty(i.properties, PROP_NOJAVA) && !hasProperty(i.properties, PROP_REF) &&!inList(fieldsToIgnore, i)»
                set«i.name.toFirstUpper»(«variable».get«i.name.toFirstUpper»());
            «ENDIF»
        «ENDFOR»
	'''
    def private static CharSequence recurseDataSetter(ClassDefinition cl, List<FieldDefinition> fieldsToIgnore, List<EmbeddableUse> embeddables) '''
    	«IF cl.extendsClass?.classRef != null»
    		«recurseDataSetter(cl.extendsClass?.classRef, fieldsToIgnore, embeddables)»
    	«ENDIF»
    	«simpleSetter("_d", cl, fieldsToIgnore)»
    '''
	
	// methods are use for the classic get$Data / set$Data as well as get$Tracking / set$Tracking
	// stopAt is currently not used!
//    def private static CharSequence recurseDataGetter(ClassDefinition cl, List<EmbeddableUse> embeddables) {
//        recurse(cl, null, true,
//                [ !properties.hasProperty(PROP_NODDL) && !properties.hasProperty(PROP_NOJAVA) && !properties.hasProperty(PROP_REF)],
//                embeddables,
//                [ '''// auto-generated data getter for «name»
//                  '''],
//                [ fld, myName, req | '''_r.set«myName.toFirstUpper»(get«myName.toFirstUpper»());
//                  ''']
//        )
//    }

	// stopAt is currently not used!
//    def private static CharSequence recurseDataSetter(ClassDefinition cl, List<FieldDefinition> fieldsToIgnore, List<EmbeddableUse> embeddables) {
//        recurse(cl, null, true,
//                [ (!inList(fieldsToIgnore, it)) && !properties.hasProperty(PROP_NOJAVA) && !properties.hasProperty(PROP_REF)],
//                embeddables,
//                [ '''// auto-generated data setter for «name»
//                  '''],
//                [ fld, myName, req | '''set«myName.toFirstUpper»(_d.get«myName.toFirstUpper»());
//                  ''']
//        )
//    }

    def public static writeDataMapperMethods(ClassDefinition pojo, boolean isRootEntity, ClassDefinition rootPojo, List<EmbeddableUse> embeddables,
    	List<FieldDefinition> fieldsNotToSet) '''
        @Override
        public String get$DataPQON() {
            return "«getPartiallyQualifiedClassName(pojo)»";
        }
        @Override
        public Class<? extends «rootPojo.name»> get$DataClass() {
            return «pojo.name».class;
        }
        «IF isRootEntity»
        public static Class<«pojo.name»> class$DataClass() {
            return «pojo.name».class;
        }
        public static String class$DataPQON() {
            return "«getPartiallyQualifiedClassName(pojo)»";
        }
        «ENDIF»
        @Override
        public «pojo.name» get$Data() throws ApplicationException {
            «pojo.name» _r = new «pojo.name»();
            «recurseDataGetter(pojo, null, embeddables)»
            return _r;
        }
        @Override
        public void set$Data(«rootPojo.name» _d) {
            «IF isRootEntity»
                «recurseDataSetter(pojo, fieldsNotToSet, embeddables)»
            «ELSE»
                super.set$Data(_d);
                if (_d instanceof «pojo.name») {
                    «pojo.name» _dd = («pojo.name»)_d;
                    // auto-generated data setter for «pojo.name»
                    «simpleSetter("_dd", pojo, fieldsNotToSet)»
                }
            «ENDIF»
        }
    '''
    
    def public static writeTrackingMapperMethods(ClassDefinition pojo, String pojoname) '''
        public static Class<«pojoname»> class$TrackingClass() {
            «IF pojo == null»
                return null;
            «ELSE»
                return «pojoname».class;
            «ENDIF»
        }
        @Override
        public String get$TrackingPQON() {
            «IF pojo == null»
                return null;
            «ELSE»
                return "«getPartiallyQualifiedClassName(pojo)»";
            «ENDIF»
        }
        @Override
        public Class<«pojoname»> get$TrackingClass() {
            «IF pojo == null»
                return null;
            «ELSE»
                return «pojoname».class;
            «ENDIF»
        }
        
        @Override
        public «pojoname» get$Tracking() throws ApplicationException {
            «IF pojo == null»
                return null;
            «ELSE»
                «pojoname» _r = new «pojoname»();
                «recurseDataGetter(pojo, null, null)»
                return _r;
            «ENDIF»
        }
        @Override
        public void set$Tracking(«pojoname» _d) {
            «IF pojo != null»
                «recurseDataSetter(pojo, null, null)»
            «ENDIF»
        }
    '''
}

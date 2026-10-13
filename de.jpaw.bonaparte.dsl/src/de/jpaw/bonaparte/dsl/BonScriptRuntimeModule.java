package de.jpaw.bonaparte.dsl;

import org.apache.log4j.Logger;
import org.eclipse.xtext.conversion.IValueConverterService;
import org.eclipse.xtext.resource.DerivedStateAwareResource;
import org.eclipse.xtext.resource.DerivedStateAwareResourceDescriptionManager;
import org.eclipse.xtext.resource.IDerivedStateComputer;
import org.eclipse.xtext.resource.IResourceDescription;
import org.eclipse.xtext.resource.XtextResource;

import de.jpaw.bonaparte.dsl.generator.CommentConverter;
import de.jpaw.bonaparte.dsl.generator.PackageEnricher;

/**
 * Use this class to register components to be used at runtime / without the Equinox extension registry.
 */
//public class BonScriptRuntimeModule extends AbstractBonScriptRuntimeModule {
//    private static Logger LOGGER = Logger.getLogger(BonScriptRuntimeModule.class);
//
//    public BonScriptRuntimeModule() {
//        LOGGER.info("BON Runtime module constructed");
//    }
//
//    @Override
//    public Class<? extends IValueConverterService> bindIValueConverterService() {
//        LOGGER.info("BON Value converter bound");
//        return CommentConverter.class;
//    }
//
//    public Class<? extends IDerivedStateComputer> bindIDerivedStateComputer() {
//        LOGGER.info("PackageEnricher bound");
//        return PackageEnricher.class;
//    }
//
//    @Override
//    public Class<? extends XtextResource> bindXtextResource() {
//        LOGGER.info("DerivedStateAwareResource bound");
//        return DerivedStateAwareResource.class;
//    }
//
//    public Class<? extends IResourceDescription.Manager> bindIResourceDescriptionManager() {
//        LOGGER.info("DerivedStateAwareResourceDescriptionManager bound");
//        return DerivedStateAwareResourceDescriptionManager.class;
//    }
//}

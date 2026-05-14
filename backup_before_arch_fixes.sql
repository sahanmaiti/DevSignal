--
-- PostgreSQL database dump
--

\restrict Zm7vmSLDl0TmVl6Di5b3EVQeSOJf2WCt2AJIwQXZvDjReYKtFwcAYC6kQEwIk9f

-- Dumped from database version 16.13
-- Dumped by pg_dump version 16.13

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: increment_workflow_version(); Type: FUNCTION; Schema: public; Owner: radar
--

CREATE FUNCTION public.increment_workflow_version() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
			BEGIN
				IF NEW."versionCounter" IS NOT DISTINCT FROM OLD."versionCounter" THEN
					NEW."versionCounter" = OLD."versionCounter" + 1;
				END IF;
				RETURN NEW;
			END;
			$$;


ALTER FUNCTION public.increment_workflow_version() OWNER TO radar;

--
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: radar
--

CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- NEW refers to the row being updated (with the new values)
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.set_updated_at() OWNER TO radar;

--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: radar
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_updated_at_column() OWNER TO radar;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: annotation_tag_entity; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.annotation_tag_entity (
    id character varying(16) NOT NULL,
    name character varying(24) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.annotation_tag_entity OWNER TO radar;

--
-- Name: applications; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.applications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    job_id integer NOT NULL,
    stage text DEFAULT 'applied'::text NOT NULL,
    applied_at timestamp with time zone DEFAULT now(),
    notes text,
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.applications OWNER TO radar;

--
-- Name: auth_identity; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.auth_identity (
    "userId" uuid,
    "providerId" character varying(255) NOT NULL,
    "providerType" character varying(32) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.auth_identity OWNER TO radar;

--
-- Name: auth_provider_sync_history; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.auth_provider_sync_history (
    id integer NOT NULL,
    "providerType" character varying(32) NOT NULL,
    "runMode" text NOT NULL,
    status text NOT NULL,
    "startedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "endedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    scanned integer NOT NULL,
    created integer NOT NULL,
    updated integer NOT NULL,
    disabled integer NOT NULL,
    error text
);


ALTER TABLE public.auth_provider_sync_history OWNER TO radar;

--
-- Name: auth_provider_sync_history_id_seq; Type: SEQUENCE; Schema: public; Owner: radar
--

CREATE SEQUENCE public.auth_provider_sync_history_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.auth_provider_sync_history_id_seq OWNER TO radar;

--
-- Name: auth_provider_sync_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: radar
--

ALTER SEQUENCE public.auth_provider_sync_history_id_seq OWNED BY public.auth_provider_sync_history.id;


--
-- Name: binary_data; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.binary_data (
    "fileId" uuid NOT NULL,
    "sourceType" character varying(50) NOT NULL,
    "sourceId" character varying(255) NOT NULL,
    data bytea NOT NULL,
    "mimeType" character varying(255),
    "fileName" character varying(255),
    "fileSize" integer NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    CONSTRAINT "CHK_binary_data_sourceType" CHECK ((("sourceType")::text = ANY ((ARRAY['execution'::character varying, 'chat_message_attachment'::character varying])::text[])))
);


ALTER TABLE public.binary_data OWNER TO radar;

--
-- Name: COLUMN binary_data."sourceType"; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.binary_data."sourceType" IS 'Source the file belongs to, e.g. ''execution''';


--
-- Name: COLUMN binary_data."sourceId"; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.binary_data."sourceId" IS 'ID of the source, e.g. execution ID';


--
-- Name: COLUMN binary_data.data; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.binary_data.data IS 'Raw, not base64 encoded';


--
-- Name: COLUMN binary_data."fileSize"; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.binary_data."fileSize" IS 'In bytes';


--
-- Name: chat_hub_agent_tools; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.chat_hub_agent_tools (
    "agentId" uuid NOT NULL,
    "toolId" uuid NOT NULL
);


ALTER TABLE public.chat_hub_agent_tools OWNER TO radar;

--
-- Name: chat_hub_agents; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.chat_hub_agents (
    id uuid NOT NULL,
    name character varying(256) NOT NULL,
    description character varying(512),
    "systemPrompt" text NOT NULL,
    "ownerId" uuid NOT NULL,
    "credentialId" character varying(36),
    provider character varying(16) NOT NULL,
    model character varying(64) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    icon json,
    files json DEFAULT '[]'::json NOT NULL,
    "suggestedPrompts" json DEFAULT '[]'::json NOT NULL
);


ALTER TABLE public.chat_hub_agents OWNER TO radar;

--
-- Name: COLUMN chat_hub_agents.provider; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.chat_hub_agents.provider IS 'ChatHubProvider enum: "openai", "anthropic", "google", "n8n"';


--
-- Name: COLUMN chat_hub_agents.model; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.chat_hub_agents.model IS 'Model name used at the respective Model node, ie. "gpt-4"';


--
-- Name: chat_hub_messages; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.chat_hub_messages (
    id uuid NOT NULL,
    "sessionId" uuid NOT NULL,
    "previousMessageId" uuid,
    "revisionOfMessageId" uuid,
    "retryOfMessageId" uuid,
    type character varying(16) NOT NULL,
    name character varying(128) NOT NULL,
    content text NOT NULL,
    provider character varying(16),
    model character varying(256),
    "workflowId" character varying(36),
    "executionId" integer,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "agentId" uuid,
    status character varying(16) DEFAULT 'success'::character varying NOT NULL,
    attachments json
);


ALTER TABLE public.chat_hub_messages OWNER TO radar;

--
-- Name: COLUMN chat_hub_messages.type; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.chat_hub_messages.type IS 'ChatHubMessageType enum: "human", "ai", "system", "tool", "generic"';


--
-- Name: COLUMN chat_hub_messages.provider; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.chat_hub_messages.provider IS 'ChatHubProvider enum: "openai", "anthropic", "google", "n8n"';


--
-- Name: COLUMN chat_hub_messages.model; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.chat_hub_messages.model IS 'Model name used at the respective Model node, ie. "gpt-4"';


--
-- Name: COLUMN chat_hub_messages."agentId"; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.chat_hub_messages."agentId" IS 'ID of the custom agent (if provider is "custom-agent")';


--
-- Name: COLUMN chat_hub_messages.status; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.chat_hub_messages.status IS 'ChatHubMessageStatus enum, eg. "success", "error", "running", "cancelled"';


--
-- Name: COLUMN chat_hub_messages.attachments; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.chat_hub_messages.attachments IS 'File attachments for the message (if any), stored as JSON. Files are stored as base64-encoded data URLs.';


--
-- Name: chat_hub_session_tools; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.chat_hub_session_tools (
    "sessionId" uuid NOT NULL,
    "toolId" uuid NOT NULL
);


ALTER TABLE public.chat_hub_session_tools OWNER TO radar;

--
-- Name: chat_hub_sessions; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.chat_hub_sessions (
    id uuid NOT NULL,
    title character varying(256) NOT NULL,
    "ownerId" uuid NOT NULL,
    "lastMessageAt" timestamp(3) with time zone NOT NULL,
    "credentialId" character varying(36),
    provider character varying(16),
    model character varying(256),
    "workflowId" character varying(36),
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "agentId" uuid,
    "agentName" character varying(128),
    type character varying(16) DEFAULT 'production'::character varying NOT NULL,
    CONSTRAINT "CHK_chat_hub_sessions_type" CHECK (((type)::text = ANY ((ARRAY['production'::character varying, 'manual'::character varying])::text[])))
);


ALTER TABLE public.chat_hub_sessions OWNER TO radar;

--
-- Name: COLUMN chat_hub_sessions.provider; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.chat_hub_sessions.provider IS 'ChatHubProvider enum: "openai", "anthropic", "google", "n8n"';


--
-- Name: COLUMN chat_hub_sessions.model; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.chat_hub_sessions.model IS 'Model name used at the respective Model node, ie. "gpt-4"';


--
-- Name: COLUMN chat_hub_sessions."agentId"; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.chat_hub_sessions."agentId" IS 'ID of the custom agent (if provider is "custom-agent")';


--
-- Name: COLUMN chat_hub_sessions."agentName"; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.chat_hub_sessions."agentName" IS 'Cached name of the custom agent (if provider is "custom-agent")';


--
-- Name: chat_hub_tools; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.chat_hub_tools (
    id uuid NOT NULL,
    name character varying(255) NOT NULL,
    type character varying(255) NOT NULL,
    "typeVersion" double precision NOT NULL,
    "ownerId" uuid NOT NULL,
    definition json NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.chat_hub_tools OWNER TO radar;

--
-- Name: companies_watchlist; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.companies_watchlist (
    id integer NOT NULL,
    company character varying(200) NOT NULL,
    ios_product_desc text DEFAULT ''::text NOT NULL,
    company_url text DEFAULT ''::text NOT NULL,
    linkedin_url text DEFAULT ''::text NOT NULL,
    funding_stage character varying(50) DEFAULT ''::character varying NOT NULL,
    notes text DEFAULT ''::text NOT NULL,
    added_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.companies_watchlist OWNER TO radar;

--
-- Name: companies_watchlist_id_seq; Type: SEQUENCE; Schema: public; Owner: radar
--

CREATE SEQUENCE public.companies_watchlist_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.companies_watchlist_id_seq OWNER TO radar;

--
-- Name: companies_watchlist_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: radar
--

ALTER SEQUENCE public.companies_watchlist_id_seq OWNED BY public.companies_watchlist.id;


--
-- Name: credential_dependency; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.credential_dependency (
    id integer NOT NULL,
    "credentialId" character varying(36) NOT NULL,
    "dependencyType" character varying(64) NOT NULL,
    "dependencyId" character varying(255) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.credential_dependency OWNER TO radar;

--
-- Name: credential_dependency_id_seq; Type: SEQUENCE; Schema: public; Owner: radar
--

ALTER TABLE public.credential_dependency ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.credential_dependency_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: credentials_entity; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.credentials_entity (
    name character varying(128) NOT NULL,
    data text NOT NULL,
    type character varying(128) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    id character varying(36) NOT NULL,
    "isManaged" boolean DEFAULT false NOT NULL,
    "isGlobal" boolean DEFAULT false NOT NULL,
    "isResolvable" boolean DEFAULT false NOT NULL,
    "resolvableAllowFallback" boolean DEFAULT false NOT NULL,
    "resolverId" character varying(16)
);


ALTER TABLE public.credentials_entity OWNER TO radar;

--
-- Name: data_table; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.data_table (
    id character varying(36) NOT NULL,
    name character varying(128) NOT NULL,
    "projectId" character varying(36) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.data_table OWNER TO radar;

--
-- Name: data_table_column; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.data_table_column (
    id character varying(36) NOT NULL,
    name character varying(128) NOT NULL,
    type character varying(32) NOT NULL,
    index integer NOT NULL,
    "dataTableId" character varying(36) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.data_table_column OWNER TO radar;

--
-- Name: COLUMN data_table_column.type; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.data_table_column.type IS 'Expected: string, number, boolean, or date (not enforced as a constraint)';


--
-- Name: COLUMN data_table_column.index; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.data_table_column.index IS 'Column order, starting from 0 (0 = first column)';


--
-- Name: device_tokens; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.device_tokens (
    id integer NOT NULL,
    token text NOT NULL,
    platform text DEFAULT 'ios'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.device_tokens OWNER TO radar;

--
-- Name: device_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: radar
--

CREATE SEQUENCE public.device_tokens_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.device_tokens_id_seq OWNER TO radar;

--
-- Name: device_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: radar
--

ALTER SEQUENCE public.device_tokens_id_seq OWNED BY public.device_tokens.id;


--
-- Name: dynamic_credential_entry; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.dynamic_credential_entry (
    credential_id character varying(16) NOT NULL,
    subject_id character varying(2048) NOT NULL,
    resolver_id character varying(16) NOT NULL,
    data text NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.dynamic_credential_entry OWNER TO radar;

--
-- Name: dynamic_credential_resolver; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.dynamic_credential_resolver (
    id character varying(16) NOT NULL,
    name character varying(128) NOT NULL,
    type character varying(128) NOT NULL,
    config text NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.dynamic_credential_resolver OWNER TO radar;

--
-- Name: COLUMN dynamic_credential_resolver.config; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.dynamic_credential_resolver.config IS 'Encrypted resolver configuration (JSON encrypted as string)';


--
-- Name: dynamic_credential_user_entry; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.dynamic_credential_user_entry (
    "credentialId" character varying(16) NOT NULL,
    "userId" uuid NOT NULL,
    "resolverId" character varying(16) NOT NULL,
    data text NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.dynamic_credential_user_entry OWNER TO radar;

--
-- Name: event_destinations; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.event_destinations (
    id uuid NOT NULL,
    destination jsonb NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.event_destinations OWNER TO radar;

--
-- Name: execution_annotation_tags; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.execution_annotation_tags (
    "annotationId" integer NOT NULL,
    "tagId" character varying(24) NOT NULL
);


ALTER TABLE public.execution_annotation_tags OWNER TO radar;

--
-- Name: execution_annotations; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.execution_annotations (
    id integer NOT NULL,
    "executionId" integer NOT NULL,
    vote character varying(6),
    note text,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.execution_annotations OWNER TO radar;

--
-- Name: execution_annotations_id_seq; Type: SEQUENCE; Schema: public; Owner: radar
--

CREATE SEQUENCE public.execution_annotations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.execution_annotations_id_seq OWNER TO radar;

--
-- Name: execution_annotations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: radar
--

ALTER SEQUENCE public.execution_annotations_id_seq OWNED BY public.execution_annotations.id;


--
-- Name: execution_data; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.execution_data (
    "executionId" integer NOT NULL,
    "workflowData" json NOT NULL,
    data text NOT NULL,
    "workflowVersionId" character varying(36)
);


ALTER TABLE public.execution_data OWNER TO radar;

--
-- Name: execution_entity; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.execution_entity (
    id integer NOT NULL,
    finished boolean NOT NULL,
    mode character varying NOT NULL,
    "retryOf" character varying,
    "retrySuccessId" character varying,
    "startedAt" timestamp(3) with time zone,
    "stoppedAt" timestamp(3) with time zone,
    "waitTill" timestamp(3) with time zone,
    status character varying NOT NULL,
    "workflowId" character varying(36) NOT NULL,
    "deletedAt" timestamp(3) with time zone,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "storedAt" character varying(2) DEFAULT 'db'::character varying NOT NULL,
    CONSTRAINT "execution_entity_storedAt_check" CHECK ((("storedAt")::text = ANY ((ARRAY['db'::character varying, 'fs'::character varying, 's3'::character varying])::text[])))
);


ALTER TABLE public.execution_entity OWNER TO radar;

--
-- Name: execution_entity_id_seq; Type: SEQUENCE; Schema: public; Owner: radar
--

CREATE SEQUENCE public.execution_entity_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.execution_entity_id_seq OWNER TO radar;

--
-- Name: execution_entity_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: radar
--

ALTER SEQUENCE public.execution_entity_id_seq OWNED BY public.execution_entity.id;


--
-- Name: execution_metadata; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.execution_metadata (
    id integer NOT NULL,
    "executionId" integer NOT NULL,
    key character varying(255) NOT NULL,
    value text NOT NULL
);


ALTER TABLE public.execution_metadata OWNER TO radar;

--
-- Name: execution_metadata_temp_id_seq; Type: SEQUENCE; Schema: public; Owner: radar
--

CREATE SEQUENCE public.execution_metadata_temp_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.execution_metadata_temp_id_seq OWNER TO radar;

--
-- Name: execution_metadata_temp_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: radar
--

ALTER SEQUENCE public.execution_metadata_temp_id_seq OWNED BY public.execution_metadata.id;


--
-- Name: folder; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.folder (
    id character varying(36) NOT NULL,
    name character varying(128) NOT NULL,
    "parentFolderId" character varying(36),
    "projectId" character varying(36) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.folder OWNER TO radar;

--
-- Name: folder_tag; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.folder_tag (
    "folderId" character varying(36) NOT NULL,
    "tagId" character varying(36) NOT NULL
);


ALTER TABLE public.folder_tag OWNER TO radar;

--
-- Name: insights_by_period; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.insights_by_period (
    id integer NOT NULL,
    "metaId" integer NOT NULL,
    type integer NOT NULL,
    value bigint NOT NULL,
    "periodUnit" integer NOT NULL,
    "periodStart" timestamp(0) with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.insights_by_period OWNER TO radar;

--
-- Name: COLUMN insights_by_period.type; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.insights_by_period.type IS '0: time_saved_minutes, 1: runtime_milliseconds, 2: success, 3: failure';


--
-- Name: COLUMN insights_by_period."periodUnit"; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.insights_by_period."periodUnit" IS '0: hour, 1: day, 2: week';


--
-- Name: insights_by_period_id_seq; Type: SEQUENCE; Schema: public; Owner: radar
--

ALTER TABLE public.insights_by_period ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.insights_by_period_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: insights_metadata; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.insights_metadata (
    "metaId" integer NOT NULL,
    "workflowId" character varying(36),
    "projectId" character varying(36),
    "workflowName" character varying(128) NOT NULL,
    "projectName" character varying(255) NOT NULL
);


ALTER TABLE public.insights_metadata OWNER TO radar;

--
-- Name: insights_metadata_metaId_seq; Type: SEQUENCE; Schema: public; Owner: radar
--

ALTER TABLE public.insights_metadata ALTER COLUMN "metaId" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public."insights_metadata_metaId_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: insights_raw; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.insights_raw (
    id integer NOT NULL,
    "metaId" integer NOT NULL,
    type integer NOT NULL,
    value bigint NOT NULL,
    "timestamp" timestamp(0) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.insights_raw OWNER TO radar;

--
-- Name: COLUMN insights_raw.type; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.insights_raw.type IS '0: time_saved_minutes, 1: runtime_milliseconds, 2: success, 3: failure';


--
-- Name: insights_raw_id_seq; Type: SEQUENCE; Schema: public; Owner: radar
--

ALTER TABLE public.insights_raw ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.insights_raw_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: installed_nodes; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.installed_nodes (
    name character varying(200) NOT NULL,
    type character varying(200) NOT NULL,
    "latestVersion" integer DEFAULT 1 NOT NULL,
    package character varying(241) NOT NULL
);


ALTER TABLE public.installed_nodes OWNER TO radar;

--
-- Name: installed_packages; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.installed_packages (
    "packageName" character varying(214) NOT NULL,
    "installedVersion" character varying(50) NOT NULL,
    "authorName" character varying(70),
    "authorEmail" character varying(70),
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.installed_packages OWNER TO radar;

--
-- Name: instance_ai_iteration_logs; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.instance_ai_iteration_logs (
    id character varying(36) NOT NULL,
    "threadId" uuid NOT NULL,
    "taskKey" character varying NOT NULL,
    entry text NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.instance_ai_iteration_logs OWNER TO radar;

--
-- Name: instance_ai_messages; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.instance_ai_messages (
    id character varying(36) NOT NULL,
    "threadId" uuid NOT NULL,
    content text NOT NULL,
    role character varying(16) NOT NULL,
    type character varying(32),
    "resourceId" character varying(255),
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.instance_ai_messages OWNER TO radar;

--
-- Name: instance_ai_observational_memory; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.instance_ai_observational_memory (
    id character varying(36) NOT NULL,
    "lookupKey" character varying(255) NOT NULL,
    scope character varying(16) NOT NULL,
    "threadId" uuid,
    "resourceId" character varying(255) NOT NULL,
    "activeObservations" text DEFAULT ''::text NOT NULL,
    "originType" character varying(32) NOT NULL,
    config text NOT NULL,
    "generationCount" integer DEFAULT 0 NOT NULL,
    "lastObservedAt" timestamp(3) with time zone,
    "pendingMessageTokens" integer DEFAULT 0 NOT NULL,
    "totalTokensObserved" integer DEFAULT 0 NOT NULL,
    "observationTokenCount" integer DEFAULT 0 NOT NULL,
    "isObserving" boolean DEFAULT false NOT NULL,
    "isReflecting" boolean DEFAULT false NOT NULL,
    "observedMessageIds" json,
    "observedTimezone" character varying,
    "bufferedObservations" text,
    "bufferedObservationTokens" integer,
    "bufferedMessageIds" json,
    "bufferedReflection" text,
    "bufferedReflectionTokens" integer,
    "bufferedReflectionInputTokens" integer,
    "reflectedObservationLineCount" integer,
    "bufferedObservationChunks" json,
    "isBufferingObservation" boolean DEFAULT false NOT NULL,
    "isBufferingReflection" boolean DEFAULT false NOT NULL,
    "lastBufferedAtTokens" integer DEFAULT 0 NOT NULL,
    "lastBufferedAtTime" timestamp(3) with time zone,
    metadata json,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.instance_ai_observational_memory OWNER TO radar;

--
-- Name: instance_ai_resources; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.instance_ai_resources (
    id character varying(255) NOT NULL,
    "workingMemory" text,
    metadata json,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.instance_ai_resources OWNER TO radar;

--
-- Name: instance_ai_run_snapshots; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.instance_ai_run_snapshots (
    "threadId" uuid NOT NULL,
    "runId" character varying(36) NOT NULL,
    "messageGroupId" character varying(36),
    "runIds" json,
    tree text NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.instance_ai_run_snapshots OWNER TO radar;

--
-- Name: instance_ai_threads; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.instance_ai_threads (
    id uuid NOT NULL,
    "resourceId" character varying(255) NOT NULL,
    title text DEFAULT ''::text NOT NULL,
    metadata json,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.instance_ai_threads OWNER TO radar;

--
-- Name: instance_ai_workflow_snapshots; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.instance_ai_workflow_snapshots (
    "runId" character varying(36) NOT NULL,
    "workflowName" character varying(255) NOT NULL,
    "resourceId" character varying(255),
    status character varying,
    snapshot text NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.instance_ai_workflow_snapshots OWNER TO radar;

--
-- Name: instance_version_history; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.instance_version_history (
    id integer NOT NULL,
    major integer NOT NULL,
    minor integer NOT NULL,
    patch integer NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.instance_version_history OWNER TO radar;

--
-- Name: instance_version_history_id_seq; Type: SEQUENCE; Schema: public; Owner: radar
--

CREATE SEQUENCE public.instance_version_history_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.instance_version_history_id_seq OWNER TO radar;

--
-- Name: instance_version_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: radar
--

ALTER SEQUENCE public.instance_version_history_id_seq OWNED BY public.instance_version_history.id;


--
-- Name: invalid_auth_token; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.invalid_auth_token (
    token character varying(512) NOT NULL,
    "expiresAt" timestamp(3) with time zone NOT NULL
);


ALTER TABLE public.invalid_auth_token OWNER TO radar;

--
-- Name: migrations; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.migrations (
    id integer NOT NULL,
    "timestamp" bigint NOT NULL,
    name character varying NOT NULL
);


ALTER TABLE public.migrations OWNER TO radar;

--
-- Name: migrations_id_seq; Type: SEQUENCE; Schema: public; Owner: radar
--

CREATE SEQUENCE public.migrations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.migrations_id_seq OWNER TO radar;

--
-- Name: migrations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: radar
--

ALTER SEQUENCE public.migrations_id_seq OWNED BY public.migrations.id;


--
-- Name: oauth_access_tokens; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.oauth_access_tokens (
    token character varying NOT NULL,
    "clientId" character varying NOT NULL,
    "userId" uuid NOT NULL
);


ALTER TABLE public.oauth_access_tokens OWNER TO radar;

--
-- Name: oauth_authorization_codes; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.oauth_authorization_codes (
    code character varying(255) NOT NULL,
    "clientId" character varying NOT NULL,
    "userId" uuid NOT NULL,
    "redirectUri" character varying NOT NULL,
    "codeChallenge" character varying NOT NULL,
    "codeChallengeMethod" character varying(255) NOT NULL,
    "expiresAt" bigint NOT NULL,
    state character varying,
    used boolean DEFAULT false NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.oauth_authorization_codes OWNER TO radar;

--
-- Name: COLUMN oauth_authorization_codes."expiresAt"; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.oauth_authorization_codes."expiresAt" IS 'Unix timestamp in milliseconds';


--
-- Name: oauth_clients; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.oauth_clients (
    id character varying NOT NULL,
    name character varying(255) NOT NULL,
    "redirectUris" json NOT NULL,
    "grantTypes" json NOT NULL,
    "clientSecret" character varying(255),
    "clientSecretExpiresAt" bigint,
    "tokenEndpointAuthMethod" character varying(255) DEFAULT 'none'::character varying NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.oauth_clients OWNER TO radar;

--
-- Name: COLUMN oauth_clients."tokenEndpointAuthMethod"; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.oauth_clients."tokenEndpointAuthMethod" IS 'Possible values: none, client_secret_basic or client_secret_post';


--
-- Name: oauth_refresh_tokens; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.oauth_refresh_tokens (
    token character varying(255) NOT NULL,
    "clientId" character varying NOT NULL,
    "userId" uuid NOT NULL,
    "expiresAt" bigint NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.oauth_refresh_tokens OWNER TO radar;

--
-- Name: COLUMN oauth_refresh_tokens."expiresAt"; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.oauth_refresh_tokens."expiresAt" IS 'Unix timestamp in milliseconds';


--
-- Name: oauth_user_consents; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.oauth_user_consents (
    id integer NOT NULL,
    "userId" uuid NOT NULL,
    "clientId" character varying NOT NULL,
    "grantedAt" bigint NOT NULL
);


ALTER TABLE public.oauth_user_consents OWNER TO radar;

--
-- Name: COLUMN oauth_user_consents."grantedAt"; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.oauth_user_consents."grantedAt" IS 'Unix timestamp in milliseconds';


--
-- Name: oauth_user_consents_id_seq; Type: SEQUENCE; Schema: public; Owner: radar
--

ALTER TABLE public.oauth_user_consents ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.oauth_user_consents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: opportunities; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.opportunities (
    id integer NOT NULL,
    date_found timestamp with time zone DEFAULT now() NOT NULL,
    job_source character varying(50) DEFAULT ''::character varying NOT NULL,
    apply_link text DEFAULT ''::text NOT NULL,
    job_hash character varying(32) NOT NULL,
    company text DEFAULT ''::character varying NOT NULL,
    role text DEFAULT ''::character varying NOT NULL,
    location text DEFAULT ''::character varying NOT NULL,
    remote character varying(10) DEFAULT 'Unknown'::character varying NOT NULL,
    visa_sponsorship character varying(10) DEFAULT 'Unknown'::character varying NOT NULL,
    experience_req character varying(100) DEFAULT ''::character varying NOT NULL,
    tech_stack text DEFAULT ''::text NOT NULL,
    description_raw text DEFAULT ''::text NOT NULL,
    recruiter_name character varying(200) DEFAULT ''::character varying NOT NULL,
    recruiter_role character varying(200) DEFAULT ''::character varying NOT NULL,
    linkedin_profile text DEFAULT ''::text NOT NULL,
    email character varying(200) DEFAULT ''::character varying NOT NULL,
    opportunity_score smallint,
    score_breakdown jsonb,
    outreach_message text DEFAULT ''::text NOT NULL,
    applied boolean DEFAULT false NOT NULL,
    response_status character varying(20) DEFAULT ''::character varying NOT NULL,
    interview_stage character varying(20) DEFAULT ''::character varying NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT opportunities_interview_stage_check CHECK (((interview_stage)::text = ANY ((ARRAY[''::character varying, 'Phone screen'::character varying, 'Technical'::character varying, 'Final round'::character varying, 'Offer'::character varying, 'Rejected'::character varying])::text[]))),
    CONSTRAINT opportunities_opportunity_score_check CHECK (((opportunity_score IS NULL) OR ((opportunity_score >= 0) AND (opportunity_score <= 100)))),
    CONSTRAINT opportunities_remote_check CHECK (((remote)::text = ANY ((ARRAY['Yes'::character varying, 'No'::character varying, 'Hybrid'::character varying, 'Unknown'::character varying])::text[]))),
    CONSTRAINT opportunities_response_status_check CHECK (((response_status)::text = ANY ((ARRAY[''::character varying, 'No response'::character varying, 'Viewed'::character varying, 'Replied'::character varying, 'Rejected'::character varying])::text[]))),
    CONSTRAINT opportunities_visa_sponsorship_check CHECK (((visa_sponsorship)::text = ANY ((ARRAY['Yes'::character varying, 'No'::character varying, 'Unknown'::character varying])::text[])))
);


ALTER TABLE public.opportunities OWNER TO radar;

--
-- Name: opportunities_id_seq; Type: SEQUENCE; Schema: public; Owner: radar
--

CREATE SEQUENCE public.opportunities_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.opportunities_id_seq OWNER TO radar;

--
-- Name: opportunities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: radar
--

ALTER SEQUENCE public.opportunities_id_seq OWNED BY public.opportunities.id;


--
-- Name: processed_data; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.processed_data (
    "workflowId" character varying(36) NOT NULL,
    context character varying(255) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    value text NOT NULL
);


ALTER TABLE public.processed_data OWNER TO radar;

--
-- Name: project; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.project (
    id character varying(36) NOT NULL,
    name character varying(255) NOT NULL,
    type character varying(36) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    icon json,
    description character varying(512),
    "creatorId" uuid
);


ALTER TABLE public.project OWNER TO radar;

--
-- Name: COLUMN project."creatorId"; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.project."creatorId" IS 'ID of the user who created the project';


--
-- Name: project_relation; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.project_relation (
    "projectId" character varying(36) NOT NULL,
    "userId" uuid NOT NULL,
    role character varying NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.project_relation OWNER TO radar;

--
-- Name: project_secrets_provider_access; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.project_secrets_provider_access (
    "secretsProviderConnectionId" integer NOT NULL,
    "projectId" character varying(36) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    role character varying(128) DEFAULT 'secretsProviderConnection:user'::character varying NOT NULL,
    CONSTRAINT "CHK_project_secrets_provider_access_role" CHECK (((role)::text = ANY ((ARRAY['secretsProviderConnection:owner'::character varying, 'secretsProviderConnection:user'::character varying])::text[])))
);


ALTER TABLE public.project_secrets_provider_access OWNER TO radar;

--
-- Name: role; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.role (
    slug character varying(128) NOT NULL,
    "displayName" text,
    description text,
    "roleType" text,
    "systemRole" boolean DEFAULT false NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.role OWNER TO radar;

--
-- Name: COLUMN role.slug; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.role.slug IS 'Unique identifier of the role for example: "global:owner"';


--
-- Name: COLUMN role."displayName"; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.role."displayName" IS 'Name used to display in the UI';


--
-- Name: COLUMN role.description; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.role.description IS 'Text describing the scope in more detail of users';


--
-- Name: COLUMN role."roleType"; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.role."roleType" IS 'Type of the role, e.g., global, project, or workflow';


--
-- Name: COLUMN role."systemRole"; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.role."systemRole" IS 'Indicates if the role is managed by the system and cannot be edited';


--
-- Name: role_mapping_rule; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.role_mapping_rule (
    id character varying(16) NOT NULL,
    expression text NOT NULL,
    role character varying(128) NOT NULL,
    type character varying(64) NOT NULL,
    "order" integer NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.role_mapping_rule OWNER TO radar;

--
-- Name: COLUMN role_mapping_rule.type; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.role_mapping_rule.type IS 'Expected values: ''instance'' (maps to a global role) or ''project'' (maps to a project role; projects linked via role_mapping_rule_project).';


--
-- Name: role_mapping_rule_project; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.role_mapping_rule_project (
    "roleMappingRuleId" character varying(16) NOT NULL,
    "projectId" character varying(36) NOT NULL
);


ALTER TABLE public.role_mapping_rule_project OWNER TO radar;

--
-- Name: role_scope; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.role_scope (
    "roleSlug" character varying(128) NOT NULL,
    "scopeSlug" character varying(128) NOT NULL
);


ALTER TABLE public.role_scope OWNER TO radar;

--
-- Name: scope; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.scope (
    slug character varying(128) NOT NULL,
    "displayName" text,
    description text
);


ALTER TABLE public.scope OWNER TO radar;

--
-- Name: COLUMN scope.slug; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.scope.slug IS 'Unique identifier of the scope for example: "project:create"';


--
-- Name: COLUMN scope."displayName"; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.scope."displayName" IS 'Name used to display in the UI';


--
-- Name: COLUMN scope.description; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.scope.description IS 'Text describing the scope in more detail of users';


--
-- Name: scrape_runs; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.scrape_runs (
    id integer NOT NULL,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    finished_at timestamp with time zone,
    jobs_found integer DEFAULT 0 NOT NULL,
    jobs_new integer DEFAULT 0 NOT NULL,
    jobs_scored integer DEFAULT 0 NOT NULL,
    errors text DEFAULT ''::text NOT NULL,
    triggered_by character varying(20) DEFAULT 'manual'::character varying NOT NULL,
    CONSTRAINT scrape_runs_triggered_by_check CHECK (((triggered_by)::text = ANY ((ARRAY['manual'::character varying, 'n8n'::character varying, 'cron'::character varying])::text[])))
);


ALTER TABLE public.scrape_runs OWNER TO radar;

--
-- Name: scrape_runs_id_seq; Type: SEQUENCE; Schema: public; Owner: radar
--

CREATE SEQUENCE public.scrape_runs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.scrape_runs_id_seq OWNER TO radar;

--
-- Name: scrape_runs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: radar
--

ALTER SEQUENCE public.scrape_runs_id_seq OWNED BY public.scrape_runs.id;


--
-- Name: secrets_provider_connection; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.secrets_provider_connection (
    id integer NOT NULL,
    "providerKey" character varying(128) NOT NULL,
    type character varying(36) NOT NULL,
    "encryptedSettings" text NOT NULL,
    "isEnabled" boolean DEFAULT false NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.secrets_provider_connection OWNER TO radar;

--
-- Name: COLUMN secrets_provider_connection.type; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.secrets_provider_connection.type IS 'Type of secrets provider. Possible values: awsSecretsManager, gcpSecretsManager, vault, azureKeyVault, infisical';


--
-- Name: secrets_provider_connection_id_seq; Type: SEQUENCE; Schema: public; Owner: radar
--

ALTER TABLE public.secrets_provider_connection ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.secrets_provider_connection_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: settings; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.settings (
    key character varying(255) NOT NULL,
    value text NOT NULL,
    "loadOnStartup" boolean DEFAULT false NOT NULL
);


ALTER TABLE public.settings OWNER TO radar;

--
-- Name: shared_credentials; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.shared_credentials (
    "credentialsId" character varying(36) NOT NULL,
    "projectId" character varying(36) NOT NULL,
    role text NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.shared_credentials OWNER TO radar;

--
-- Name: shared_workflow; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.shared_workflow (
    "workflowId" character varying(36) NOT NULL,
    "projectId" character varying(36) NOT NULL,
    role text NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.shared_workflow OWNER TO radar;

--
-- Name: tag_entity; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.tag_entity (
    name character varying(24) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    id character varying(36) NOT NULL
);


ALTER TABLE public.tag_entity OWNER TO radar;

--
-- Name: test_case_execution; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.test_case_execution (
    id character varying(36) NOT NULL,
    "testRunId" character varying(36) NOT NULL,
    "executionId" integer,
    status character varying NOT NULL,
    "runAt" timestamp(3) with time zone,
    "completedAt" timestamp(3) with time zone,
    "errorCode" character varying,
    "errorDetails" json,
    metrics json,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    inputs json,
    outputs json
);


ALTER TABLE public.test_case_execution OWNER TO radar;

--
-- Name: test_run; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.test_run (
    id character varying(36) NOT NULL,
    "workflowId" character varying(36) NOT NULL,
    status character varying NOT NULL,
    "errorCode" character varying,
    "errorDetails" json,
    "runAt" timestamp(3) with time zone,
    "completedAt" timestamp(3) with time zone,
    metrics json,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "runningInstanceId" character varying(255),
    "cancelRequested" boolean DEFAULT false NOT NULL
);


ALTER TABLE public.test_run OWNER TO radar;

--
-- Name: token_exchange_jti; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.token_exchange_jti (
    jti character varying(255) NOT NULL,
    "expiresAt" timestamp(3) with time zone NOT NULL,
    "createdAt" timestamp(3) with time zone NOT NULL
);


ALTER TABLE public.token_exchange_jti OWNER TO radar;

--
-- Name: user; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public."user" (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email character varying(255),
    "firstName" character varying(32),
    "lastName" character varying(32),
    password character varying(255),
    "personalizationAnswers" json,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    settings json,
    disabled boolean DEFAULT false NOT NULL,
    "mfaEnabled" boolean DEFAULT false NOT NULL,
    "mfaSecret" text,
    "mfaRecoveryCodes" text,
    "lastActiveAt" date,
    "roleSlug" character varying(128) DEFAULT 'global:member'::character varying NOT NULL
);


ALTER TABLE public."user" OWNER TO radar;

--
-- Name: user_api_keys; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.user_api_keys (
    id character varying(36) NOT NULL,
    "userId" uuid NOT NULL,
    label character varying(100) NOT NULL,
    "apiKey" character varying NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    scopes json,
    audience character varying DEFAULT 'public-api'::character varying NOT NULL
);


ALTER TABLE public.user_api_keys OWNER TO radar;

--
-- Name: variables; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.variables (
    key character varying(50) NOT NULL,
    type character varying(50) DEFAULT 'string'::character varying NOT NULL,
    value character varying(255),
    id character varying(36) NOT NULL,
    "projectId" character varying(36)
);


ALTER TABLE public.variables OWNER TO radar;

--
-- Name: webhook_entity; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.webhook_entity (
    "webhookPath" character varying NOT NULL,
    method character varying NOT NULL,
    node character varying NOT NULL,
    "webhookId" character varying,
    "pathLength" integer,
    "workflowId" character varying(36) NOT NULL
);


ALTER TABLE public.webhook_entity OWNER TO radar;

--
-- Name: workflow_builder_session; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.workflow_builder_session (
    id uuid NOT NULL,
    "workflowId" character varying(36) NOT NULL,
    "userId" uuid NOT NULL,
    messages json DEFAULT '[]'::json NOT NULL,
    "previousSummary" text,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "activeVersionCardId" character varying(255),
    "resumeAfterRestoreMessageId" character varying(255)
);


ALTER TABLE public.workflow_builder_session OWNER TO radar;

--
-- Name: COLUMN workflow_builder_session."previousSummary"; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.workflow_builder_session."previousSummary" IS 'Summary of prior conversation from compaction (/compact or auto-compact)';


--
-- Name: workflow_dependency; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.workflow_dependency (
    id integer NOT NULL,
    "workflowId" character varying(36) NOT NULL,
    "workflowVersionId" integer NOT NULL,
    "dependencyType" character varying(32) NOT NULL,
    "dependencyKey" character varying(255) NOT NULL,
    "dependencyInfo" json,
    "indexVersionId" smallint DEFAULT 1 NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "publishedVersionId" character varying(36)
);


ALTER TABLE public.workflow_dependency OWNER TO radar;

--
-- Name: COLUMN workflow_dependency."workflowVersionId"; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.workflow_dependency."workflowVersionId" IS 'Version of the workflow';


--
-- Name: COLUMN workflow_dependency."dependencyType"; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.workflow_dependency."dependencyType" IS 'Type of dependency: "credential", "nodeType", "webhookPath", or "workflowCall"';


--
-- Name: COLUMN workflow_dependency."dependencyKey"; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.workflow_dependency."dependencyKey" IS 'ID or name of the dependency';


--
-- Name: COLUMN workflow_dependency."dependencyInfo"; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.workflow_dependency."dependencyInfo" IS 'Additional info about the dependency, interpreted based on type';


--
-- Name: COLUMN workflow_dependency."indexVersionId"; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.workflow_dependency."indexVersionId" IS 'Version of the index structure';


--
-- Name: workflow_dependency_id_seq; Type: SEQUENCE; Schema: public; Owner: radar
--

ALTER TABLE public.workflow_dependency ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.workflow_dependency_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: workflow_entity; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.workflow_entity (
    name character varying(128) NOT NULL,
    active boolean NOT NULL,
    nodes json NOT NULL,
    connections json NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    settings json,
    "staticData" json,
    "pinData" json,
    "versionId" character(36) NOT NULL,
    "triggerCount" integer DEFAULT 0 NOT NULL,
    id character varying(36) NOT NULL,
    meta json,
    "parentFolderId" character varying(36) DEFAULT NULL::character varying,
    "isArchived" boolean DEFAULT false NOT NULL,
    "versionCounter" integer DEFAULT 1 NOT NULL,
    description text,
    "activeVersionId" character varying(36)
);


ALTER TABLE public.workflow_entity OWNER TO radar;

--
-- Name: workflow_history; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.workflow_history (
    "versionId" character varying(36) NOT NULL,
    "workflowId" character varying(36) NOT NULL,
    authors character varying(255) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    nodes json NOT NULL,
    connections json NOT NULL,
    name character varying(128),
    autosaved boolean DEFAULT false NOT NULL,
    description text
);


ALTER TABLE public.workflow_history OWNER TO radar;

--
-- Name: workflow_publish_history; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.workflow_publish_history (
    id integer NOT NULL,
    "workflowId" character varying(36) NOT NULL,
    "versionId" character varying(36) NOT NULL,
    event character varying(36) NOT NULL,
    "userId" uuid,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    CONSTRAINT "CHK_workflow_publish_history_event" CHECK (((event)::text = ANY ((ARRAY['activated'::character varying, 'deactivated'::character varying])::text[])))
);


ALTER TABLE public.workflow_publish_history OWNER TO radar;

--
-- Name: COLUMN workflow_publish_history.event; Type: COMMENT; Schema: public; Owner: radar
--

COMMENT ON COLUMN public.workflow_publish_history.event IS 'Type of history record: activated (workflow is now active), deactivated (workflow is now inactive)';


--
-- Name: workflow_publish_history_id_seq; Type: SEQUENCE; Schema: public; Owner: radar
--

ALTER TABLE public.workflow_publish_history ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.workflow_publish_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: workflow_published_version; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.workflow_published_version (
    "workflowId" character varying(36) NOT NULL,
    "publishedVersionId" character varying(36) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.workflow_published_version OWNER TO radar;

--
-- Name: workflow_statistics; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.workflow_statistics (
    count bigint DEFAULT 0,
    "latestEvent" timestamp(3) with time zone,
    name character varying(128) NOT NULL,
    "workflowId" character varying(36) NOT NULL,
    "rootCount" bigint DEFAULT 0,
    id integer NOT NULL,
    "workflowName" character varying(128)
);


ALTER TABLE public.workflow_statistics OWNER TO radar;

--
-- Name: workflow_statistics_id_seq; Type: SEQUENCE; Schema: public; Owner: radar
--

CREATE SEQUENCE public.workflow_statistics_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.workflow_statistics_id_seq OWNER TO radar;

--
-- Name: workflow_statistics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: radar
--

ALTER SEQUENCE public.workflow_statistics_id_seq OWNED BY public.workflow_statistics.id;


--
-- Name: workflows_tags; Type: TABLE; Schema: public; Owner: radar
--

CREATE TABLE public.workflows_tags (
    "workflowId" character varying(36) NOT NULL,
    "tagId" character varying(36) NOT NULL
);


ALTER TABLE public.workflows_tags OWNER TO radar;

--
-- Name: auth_provider_sync_history id; Type: DEFAULT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.auth_provider_sync_history ALTER COLUMN id SET DEFAULT nextval('public.auth_provider_sync_history_id_seq'::regclass);


--
-- Name: companies_watchlist id; Type: DEFAULT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.companies_watchlist ALTER COLUMN id SET DEFAULT nextval('public.companies_watchlist_id_seq'::regclass);


--
-- Name: device_tokens id; Type: DEFAULT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.device_tokens ALTER COLUMN id SET DEFAULT nextval('public.device_tokens_id_seq'::regclass);


--
-- Name: execution_annotations id; Type: DEFAULT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.execution_annotations ALTER COLUMN id SET DEFAULT nextval('public.execution_annotations_id_seq'::regclass);


--
-- Name: execution_entity id; Type: DEFAULT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.execution_entity ALTER COLUMN id SET DEFAULT nextval('public.execution_entity_id_seq'::regclass);


--
-- Name: execution_metadata id; Type: DEFAULT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.execution_metadata ALTER COLUMN id SET DEFAULT nextval('public.execution_metadata_temp_id_seq'::regclass);


--
-- Name: instance_version_history id; Type: DEFAULT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.instance_version_history ALTER COLUMN id SET DEFAULT nextval('public.instance_version_history_id_seq'::regclass);


--
-- Name: migrations id; Type: DEFAULT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.migrations ALTER COLUMN id SET DEFAULT nextval('public.migrations_id_seq'::regclass);


--
-- Name: opportunities id; Type: DEFAULT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.opportunities ALTER COLUMN id SET DEFAULT nextval('public.opportunities_id_seq'::regclass);


--
-- Name: scrape_runs id; Type: DEFAULT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.scrape_runs ALTER COLUMN id SET DEFAULT nextval('public.scrape_runs_id_seq'::regclass);


--
-- Name: workflow_statistics id; Type: DEFAULT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.workflow_statistics ALTER COLUMN id SET DEFAULT nextval('public.workflow_statistics_id_seq'::regclass);


--
-- Data for Name: annotation_tag_entity; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.annotation_tag_entity (id, name, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: applications; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.applications (id, job_id, stage, applied_at, notes, updated_at) FROM stdin;
2c8e98e4-410a-42be-bad5-ab449e96cbe7	98	applied	2026-05-04 06:10:37.699058+00	\N	2026-05-04 06:10:37.699058+00
2f0a17be-f20e-43d0-b531-22a8c498287b	91	applied	2026-05-03 21:52:51.143106+00	\N	2026-05-04 14:10:09.495048+00
34866ad5-0f58-49d3-ba71-c875ed01e6e4	95	applied	2026-05-04 15:33:54.28666+00	\N	2026-05-04 22:04:25.059194+00
876bb153-7231-4bbc-a479-48f2fb0690aa	119	applied	2026-05-04 15:24:38.12429+00	\N	2026-05-05 16:17:30.73908+00
3bd84ce2-355a-4a5e-8690-614ff599f226	100	applied	2026-05-07 07:41:43.417849+00	\N	2026-05-09 10:00:49.51139+00
\.


--
-- Data for Name: auth_identity; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.auth_identity ("userId", "providerId", "providerType", "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: auth_provider_sync_history; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.auth_provider_sync_history (id, "providerType", "runMode", status, "startedAt", "endedAt", scanned, created, updated, disabled, error) FROM stdin;
\.


--
-- Data for Name: binary_data; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.binary_data ("fileId", "sourceType", "sourceId", data, "mimeType", "fileName", "fileSize", "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: chat_hub_agent_tools; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.chat_hub_agent_tools ("agentId", "toolId") FROM stdin;
\.


--
-- Data for Name: chat_hub_agents; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.chat_hub_agents (id, name, description, "systemPrompt", "ownerId", "credentialId", provider, model, "createdAt", "updatedAt", icon, files, "suggestedPrompts") FROM stdin;
\.


--
-- Data for Name: chat_hub_messages; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.chat_hub_messages (id, "sessionId", "previousMessageId", "revisionOfMessageId", "retryOfMessageId", type, name, content, provider, model, "workflowId", "executionId", "createdAt", "updatedAt", "agentId", status, attachments) FROM stdin;
\.


--
-- Data for Name: chat_hub_session_tools; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.chat_hub_session_tools ("sessionId", "toolId") FROM stdin;
\.


--
-- Data for Name: chat_hub_sessions; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.chat_hub_sessions (id, title, "ownerId", "lastMessageAt", "credentialId", provider, model, "workflowId", "createdAt", "updatedAt", "agentId", "agentName", type) FROM stdin;
\.


--
-- Data for Name: chat_hub_tools; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.chat_hub_tools (id, name, type, "typeVersion", "ownerId", definition, enabled, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: companies_watchlist; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.companies_watchlist (id, company, ios_product_desc, company_url, linkedin_url, funding_stage, notes, added_at) FROM stdin;
1	Razorpay	iOS payment SDK and merchant app					2026-04-24 07:38:37.683241+00
2	CRED	iOS-first credit card rewards app					2026-04-24 07:38:44.720558+00
3	Zepto	iOS grocery delivery app					2026-04-24 07:38:49.963173+00
4	Groww	iOS stock and mutual funds investing app					2026-04-24 07:38:54.546718+00
\.


--
-- Data for Name: credential_dependency; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.credential_dependency (id, "credentialId", "dependencyType", "dependencyId", "createdAt") FROM stdin;
\.


--
-- Data for Name: credentials_entity; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.credentials_entity (name, data, type, "createdAt", "updatedAt", id, "isManaged", "isGlobal", "isResolvable", "resolvableAllowFallback", "resolverId") FROM stdin;
\.


--
-- Data for Name: data_table; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.data_table (id, name, "projectId", "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: data_table_column; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.data_table_column (id, name, type, index, "dataTableId", "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: device_tokens; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.device_tokens (id, token, platform, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: dynamic_credential_entry; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.dynamic_credential_entry (credential_id, subject_id, resolver_id, data, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: dynamic_credential_resolver; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.dynamic_credential_resolver (id, name, type, config, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: dynamic_credential_user_entry; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.dynamic_credential_user_entry ("credentialId", "userId", "resolverId", data, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: event_destinations; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.event_destinations (id, destination, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: execution_annotation_tags; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.execution_annotation_tags ("annotationId", "tagId") FROM stdin;
\.


--
-- Data for Name: execution_annotations; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.execution_annotations (id, "executionId", vote, note, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: execution_data; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.execution_data ("executionId", "workflowData", data, "workflowVersionId") FROM stdin;
14	{"id":"AlrynH2aZBv1h5NT","name":"DevSignal — Main Pipeline","active":false,"activeVersionId":null,"isArchived":false,"createdAt":"2026-04-24T14:28:48.417Z","updatedAt":"2026-05-05T07:59:13.763Z","nodes":[{"parameters":{"notice":"","rule":{"interval":[{"field":"hours","hoursInterval":12,"triggerAtMinute":0}]}},"id":"b38e6f47-0ed0-45d9-a630-e43103d9b9a4","name":"Every 12 Hours","type":"n8n-nodes-base.scheduleTrigger","typeVersion":1.2,"position":[-480,128]},{"parameters":{"curlImport":"","method":"POST","url":"http://host.docker.internal:8000/run-pipeline","authentication":"none","provideSslCertificates":false,"sendQuery":false,"sendHeaders":true,"specifyHeaders":"keypair","headerParameters":{"parameters":[{"name":"X-Api-Key","value":"devsignal-local-key-2024"}]},"sendBody":false,"options":{"response":{"response":{"fullResponse":true,"neverError":false,"responseFormat":"autodetect"}},"timeout":4000000},"infoMessage":""},"id":"9616ca6d-5bb5-4253-a71f-8b0ce2579597","name":"Trigger Pipeline","type":"n8n-nodes-base.httpRequest","typeVersion":4.2,"position":[-240,128],"onError":"continueErrorOutput"},{"parameters":{"mode":"runOnceForAllItems","language":"javaScript","jsCode":"const response = $input.first().json;\\nconst body = response.body || response;\\nconsole.log('Pipeline status:', body.status);\\nconsole.log('Preview:', (body.preview || '').slice(-300));\\nreturn [{ json: { status: 'success', data: body } }];","notice":""},"id":"e8edd62b-4643-469c-9e33-08d99f49cbd6","name":"Log Success","type":"n8n-nodes-base.code","typeVersion":2,"position":[0,0]},{"parameters":{"mode":"runOnceForAllItems","language":"javaScript","jsCode":"const error = $input.first().json;\\nconst detail = error.error?.detail || error.message || 'Unknown error';\\nconst msg = typeof detail === 'object' ? JSON.stringify(detail) : String(detail);\\nconsole.error('Pipeline failed:', msg.slice(0, 500));\\nreturn [{ json: { status: 'failed', error_message: msg.slice(0, 1000) } }];","notice":""},"id":"c35065a3-6aa5-4045-be9b-09be07881794","name":"Parse Error","type":"n8n-nodes-base.code","typeVersion":2,"position":[0,240]},{"parameters":{"curlImport":"","method":"POST","url":"=https://api.telegram.org/bot{{ $env.TELEGRAM_BOT_TOKEN }}/sendMessage","authentication":"none","provideSslCertificates":false,"sendQuery":false,"sendHeaders":false,"sendBody":true,"contentType":"json","specifyBody":"keypair","bodyParameters":{"parameters":[{"name":"","value":""}]},"options":{},"infoMessage":""},"id":"8e6ca49a-ea77-4b21-921b-c447b52a6954","name":"Telegram Error Alert","type":"n8n-nodes-base.httpRequest","typeVersion":4.2,"position":[240,240]}],"connections":{"Every 12 Hours":{"main":[[{"node":"Trigger Pipeline","type":"main","index":0}]]},"Trigger Pipeline":{"main":[[{"node":"Log Success","type":"main","index":0}],[{"node":"Parse Error","type":"main","index":0}]]},"Parse Error":{"main":[[{"node":"Telegram Error Alert","type":"main","index":0}]]}},"settings":{"executionOrder":"v1","binaryMode":"separate"},"staticData":{"node:Every 12 Hours":{"recurrenceRules":[2]}},"pinData":{}}	[{"version":1,"startData":"1","resultData":"2","executionData":"3","resumeToken":"4"},{"destinationNode":"5","runNodeFilter":"6"},{"runData":"7","pinData":"8","lastNodeExecuted":"9"},{"contextData":"10","nodeExecutionStack":"11","metadata":"12","waitingExecution":"13","waitingExecutionSource":"14","runtimeData":"15"},"592ebf39486041c00339f91e494e5c346535a7e4e6bd59420fd69e77684db6da",{"nodeName":"9","mode":"16"},["17","9"],{"Every 12 Hours":"18","Trigger Pipeline":"19"},{},"Trigger Pipeline",{"node:Trigger Pipeline":"20"},[],{},{},{},{"version":1,"establishedAt":1777977565382,"source":"21","redaction":"22","triggerNode":"23"},"inclusive","Every 12 Hours",["24"],["25"],{"response":"26"},"manual",{"version":1,"policy":"27"},{"name":"9","type":"28"},{"startTime":1777977546105,"executionIndex":0,"source":"29","hints":"30","executionTime":1,"executionStatus":"31","data":"32"},{"startTime":1777977565388,"executionIndex":1,"source":"33","hints":"34","executionTime":32,"executionStatus":"31","data":"35"},{"body":"36","headers":"37","statusCode":200,"statusMessage":"38"},"none","n8n-nodes-base.httpRequest",[],[],"success",{"main":"39"},["40"],[],{"main":"41"},{"status":"42","pid":30414,"message":"43"},{"date":"44","server":"45","content-length":"46","content-type":"47","connection":"48"},"OK",["49"],{"previousNode":"17","previousNodeOutput":0,"previousNodeRun":0},["50","51"],"started","Pipeline triggered successfully","Tue, 05 May 2026 10:39:25 GMT","uvicorn","76","application/json","close",["52"],["53"],[],{"json":"54","pairedItem":"55"},{"json":"56","pairedItem":"57"},{"timestamp":"58","Readable date":"59","Readable time":"60","Day of week":"61","Year":"62","Month":"63","Day of month":"64","Hour":"65","Minute":"66","Second":"67","Timezone":"68"},{"item":0},{"body":"36","headers":"37","statusCode":200,"statusMessage":"38"},{"item":0},"2026-05-05T16:09:06.106+05:30","May 5th 2026, 4:09:06 pm","4:09:06 pm","Tuesday","2026","May","05","16","09","06","Asia/Kolkata (UTC+05:30)"]	c2fe07de-5bfc-470d-94ed-072de0da5de1
7	{"id":"AlrynH2aZBv1h5NT","name":"DevSignal — Main Pipeline","active":true,"activeVersionId":"5a0a6977-9d22-4843-8ac9-8a83b8c0ec97","isArchived":false,"createdAt":"2026-04-24T14:28:48.417Z","updatedAt":"2026-04-24T14:28:48.417Z","nodes":[{"parameters":{"notice":"","rule":{"interval":[{"field":"hours","hoursInterval":12,"triggerAtMinute":0}]}},"id":"b38e6f47-0ed0-45d9-a630-e43103d9b9a4","name":"Every 12 Hours","type":"n8n-nodes-base.scheduleTrigger","typeVersion":1.2,"position":[-480,128]},{"parameters":{"curlImport":"","method":"POST","url":"http://host.docker.internal:8000/run-pipeline","authentication":"none","provideSslCertificates":false,"sendQuery":false,"sendHeaders":true,"specifyHeaders":"keypair","headerParameters":{"parameters":[{"name":"X-Api-Key","value":"devsignal-local-key-2024"}]},"sendBody":false,"options":{"response":{"response":{"fullResponse":true,"neverError":false,"responseFormat":"autodetect"}},"timeout":1800000},"infoMessage":""},"id":"9616ca6d-5bb5-4253-a71f-8b0ce2579597","name":"Trigger Pipeline","type":"n8n-nodes-base.httpRequest","typeVersion":4.2,"position":[-240,128],"onError":"continueErrorOutput"},{"parameters":{"mode":"runOnceForAllItems","language":"javaScript","jsCode":"const response = $input.first().json;\\nconst body = response.body || response;\\nconsole.log('Pipeline status:', body.status);\\nconsole.log('Preview:', (body.preview || '').slice(-300));\\nreturn [{ json: { status: 'success', data: body } }];","notice":""},"id":"e8edd62b-4643-469c-9e33-08d99f49cbd6","name":"Log Success","type":"n8n-nodes-base.code","typeVersion":2,"position":[0,0]},{"parameters":{"mode":"runOnceForAllItems","language":"javaScript","jsCode":"const error = $input.first().json;\\nconst detail = error.error?.detail || error.message || 'Unknown error';\\nconst msg = typeof detail === 'object' ? JSON.stringify(detail) : String(detail);\\nconsole.error('Pipeline failed:', msg.slice(0, 500));\\nreturn [{ json: { status: 'failed', error_message: msg.slice(0, 1000) } }];","notice":""},"id":"c35065a3-6aa5-4045-be9b-09be07881794","name":"Parse Error","type":"n8n-nodes-base.code","typeVersion":2,"position":[0,240]},{"parameters":{"curlImport":"","method":"POST","url":"=https://api.telegram.org/bot{{ $env.TELEGRAM_BOT_TOKEN }}/sendMessage","authentication":"none","provideSslCertificates":false,"sendQuery":false,"sendHeaders":false,"sendBody":true,"contentType":"json","specifyBody":"keypair","bodyParameters":{"parameters":[{"name":"","value":""}]},"options":{},"infoMessage":""},"id":"8e6ca49a-ea77-4b21-921b-c447b52a6954","name":"Telegram Error Alert","type":"n8n-nodes-base.httpRequest","typeVersion":4.2,"position":[240,240]}],"connections":{"Every 12 Hours":{"main":[[{"node":"Trigger Pipeline","type":"main","index":0}]]},"Trigger Pipeline":{"main":[[{"node":"Log Success","type":"main","index":0}],[{"node":"Parse Error","type":"main","index":0}]]},"Parse Error":{"main":[[{"node":"Telegram Error Alert","type":"main","index":0}]]}},"settings":{"executionOrder":"v1","binaryMode":"separate"},"staticData":{"node:Every 12 Hours":{"recurrenceRules":[2]}},"pinData":{}}	[{"version":1,"startData":"1","resultData":"2","executionData":"3","resumeToken":"4"},{},{"runData":"5","lastNodeExecuted":"6"},{"contextData":"7","nodeExecutionStack":"8","metadata":"9","waitingExecution":"10","waitingExecutionSource":"11","runtimeData":"12"},"8af7ef3689c83ce546dcb854b92c86ec8d337c59ef7b00d38c05a9e4151018f3",{"Every 12 Hours":"13","Trigger Pipeline":"14","Log Success":"15"},"Log Success",{},[],{},{},{},{"version":1,"establishedAt":1777582182471,"source":"16","redaction":"17","triggerNode":"18"},["19"],["20"],["21"],"trigger",{"version":1,"policy":"22"},{"name":"23","type":"24"},{"startTime":1777582182472,"executionIndex":0,"source":"25","hints":"26","executionTime":1,"executionStatus":"27","data":"28"},{"startTime":1777582182474,"executionIndex":1,"source":"29","hints":"30","executionTime":132988,"executionStatus":"27","data":"31"},{"startTime":1777582315463,"executionIndex":2,"source":"32","hints":"33","executionTime":39,"executionStatus":"27","data":"34"},"none","Every 12 Hours","n8n-nodes-base.scheduleTrigger",[],[],"success",{"main":"35"},["36"],[],{"main":"37"},["38"],[],{"main":"39"},["40"],{"previousNode":"23","previousNodeOutput":0,"previousNodeRun":0},["41","42"],{"previousNode":"43","previousNodeOutput":0,"previousNodeRun":0},["44"],["45"],["46"],[],"Trigger Pipeline",["47"],{"json":"48","pairedItem":"49"},{"json":"50","pairedItem":"51"},{"json":"52","pairedItem":"53"},{"timestamp":"54","Readable date":"55","Readable time":"56","Day of week":"57","Year":"58","Month":"59","Day of month":"60","Hour":"61","Minute":"62","Second":"63","Timezone":"64"},{"item":0},{"body":"65","headers":"66","statusCode":200,"statusMessage":"67"},{"item":0},{"status":"27","data":"68"},{"item":0},"2026-05-01T02:19:42.426+05:30","May 1st 2026, 2:19:42 am","2:19:42 am","Friday","2026","May","01","02","19","42","Asia/Kolkata (UTC+05:30)",{"status":"27","started":"69","finished":"70","preview":"71"},{"date":"72","server":"73","content-length":"74","content-type":"75","connection":"76"},"OK",{"status":"27","started":"69","finished":"70","preview":"71"},"2026-04-30T20:49:42.526371+00:00","2026-04-30T20:51:55.416212+00:00","adar_pass@localhost:5433/...\\n[DB] Connection pool ready (1-5 connections)\\n\\n════════════════════════════════════════════════════════════\\n  DevSignal — Recruiter Enricher\\n════════════════════════════════════════════════════════════\\n\\n[Hunter] Remaining quota this month: 60 searches\\n\\n[DB] Fetching jobs with score >= 70...\\n[DB] All qualifying jobs are already enriched.\\n\\n============================================\\n  Pipeline complete — 2026-05-01 02:21:55\\n============================================\\n","Thu, 30 Apr 2026 20:49:42 GMT","uvicorn","883","application/json","close"]	5a0a6977-9d22-4843-8ac9-8a83b8c0ec97
8	{"id":"AlrynH2aZBv1h5NT","name":"DevSignal — Main Pipeline","active":false,"activeVersionId":null,"isArchived":false,"createdAt":"2026-04-24T14:28:48.417Z","updatedAt":"2026-04-24T14:28:48.417Z","nodes":[{"parameters":{"notice":"","rule":{"interval":[{"field":"hours","hoursInterval":12,"triggerAtMinute":0}]}},"id":"b38e6f47-0ed0-45d9-a630-e43103d9b9a4","name":"Every 12 Hours","type":"n8n-nodes-base.scheduleTrigger","typeVersion":1.2,"position":[-480,128]},{"parameters":{"curlImport":"","method":"POST","url":"http://host.docker.internal:8000/run-pipeline","authentication":"none","provideSslCertificates":false,"sendQuery":false,"sendHeaders":true,"specifyHeaders":"keypair","headerParameters":{"parameters":[{"name":"X-Api-Key","value":"devsignal-local-key-2024"}]},"sendBody":false,"options":{"response":{"response":{"fullResponse":true,"neverError":false,"responseFormat":"autodetect"}},"timeout":1800000},"infoMessage":""},"id":"9616ca6d-5bb5-4253-a71f-8b0ce2579597","name":"Trigger Pipeline","type":"n8n-nodes-base.httpRequest","typeVersion":4.2,"position":[-240,128],"onError":"continueErrorOutput"},{"parameters":{"mode":"runOnceForAllItems","language":"javaScript","jsCode":"const response = $input.first().json;\\nconst body = response.body || response;\\nconsole.log('Pipeline status:', body.status);\\nconsole.log('Preview:', (body.preview || '').slice(-300));\\nreturn [{ json: { status: 'success', data: body } }];","notice":""},"id":"e8edd62b-4643-469c-9e33-08d99f49cbd6","name":"Log Success","type":"n8n-nodes-base.code","typeVersion":2,"position":[0,0]},{"parameters":{"mode":"runOnceForAllItems","language":"javaScript","jsCode":"const error = $input.first().json;\\nconst detail = error.error?.detail || error.message || 'Unknown error';\\nconst msg = typeof detail === 'object' ? JSON.stringify(detail) : String(detail);\\nconsole.error('Pipeline failed:', msg.slice(0, 500));\\nreturn [{ json: { status: 'failed', error_message: msg.slice(0, 1000) } }];","notice":""},"id":"c35065a3-6aa5-4045-be9b-09be07881794","name":"Parse Error","type":"n8n-nodes-base.code","typeVersion":2,"position":[0,240]},{"parameters":{"curlImport":"","method":"POST","url":"=https://api.telegram.org/bot{{ $env.TELEGRAM_BOT_TOKEN }}/sendMessage","authentication":"none","provideSslCertificates":false,"sendQuery":false,"sendHeaders":false,"sendBody":true,"contentType":"json","specifyBody":"keypair","bodyParameters":{"parameters":[{"name":"","value":""}]},"options":{},"infoMessage":""},"id":"8e6ca49a-ea77-4b21-921b-c447b52a6954","name":"Telegram Error Alert","type":"n8n-nodes-base.httpRequest","typeVersion":4.2,"position":[240,240]}],"connections":{"Every 12 Hours":{"main":[[{"node":"Trigger Pipeline","type":"main","index":0}]]},"Trigger Pipeline":{"main":[[{"node":"Log Success","type":"main","index":0}],[{"node":"Parse Error","type":"main","index":0}]]},"Parse Error":{"main":[[{"node":"Telegram Error Alert","type":"main","index":0}]]}},"settings":{"executionOrder":"v1","binaryMode":"separate"},"staticData":{"node:Every 12 Hours":{"recurrenceRules":[2]}},"pinData":{}}	[{"version":1,"startData":"1","resultData":"2","executionData":"3","resumeToken":"4"},{},{"runData":"5","pinData":"6","lastNodeExecuted":"7"},{"contextData":"8","nodeExecutionStack":"9","metadata":"10","waitingExecution":"11","waitingExecutionSource":"12","runtimeData":"13"},"112ff34ec5411b54448b2d1b1b3731214de61dc230820c0433c53f2e1f1df5e6",{"Every 12 Hours":"14","Trigger Pipeline":"15","Log Success":"16"},{},"Log Success",{"node:Trigger Pipeline":"17"},[],{},{},{},{"version":1,"establishedAt":1777827088092,"source":"18","redaction":"19","triggerNode":"20"},["21"],["22"],["23"],{"response":"24"},"manual",{"version":1,"policy":"25"},{"name":"26","type":"27"},{"startTime":1777827088103,"executionIndex":0,"source":"28","hints":"29","executionTime":8,"executionStatus":"30","data":"31"},{"startTime":1777827088112,"executionIndex":1,"source":"32","hints":"33","executionTime":76,"executionStatus":"30","data":"34"},{"startTime":1777827088188,"executionIndex":2,"source":"35","hints":"36","executionTime":221,"executionStatus":"30","data":"37"},{"body":"38","headers":"39","statusCode":200,"statusMessage":"40"},"none","Every 12 Hours","n8n-nodes-base.scheduleTrigger",[],[],"success",{"main":"41"},["42"],[],{"main":"43"},["44"],[],{"main":"45"},{"status":"46","pid":56281,"message":"47"},{"date":"48","server":"49","content-length":"50","content-type":"51","connection":"52"},"OK",["53"],{"previousNode":"26","previousNodeOutput":0,"previousNodeRun":0},["54","55"],{"previousNode":"56","previousNodeOutput":0,"previousNodeRun":0},["57"],"started","Pipeline triggered successfully","Sun, 03 May 2026 16:51:27 GMT","uvicorn","76","application/json","close",["58"],["59"],[],"Trigger Pipeline",["60"],{"json":"61","pairedItem":"62"},{"json":"63","pairedItem":"64"},{"json":"65","pairedItem":"66"},{"timestamp":"67","Readable date":"68","Readable time":"69","Day of week":"70","Year":"71","Month":"72","Day of month":"73","Hour":"74","Minute":"75","Second":"76","Timezone":"77"},{"item":0},{"body":"38","headers":"39","statusCode":200,"statusMessage":"40"},{"item":0},{"status":"30","data":"78"},{"item":0},"2026-05-03T22:21:28.107+05:30","May 3rd 2026, 10:21:28 pm","10:21:28 pm","Sunday","2026","May","03","22","21","28","Asia/Kolkata (UTC+05:30)",{"status":"46","pid":56281,"message":"47"}]	5a0a6977-9d22-4843-8ac9-8a83b8c0ec97
9	{"id":"AlrynH2aZBv1h5NT","name":"DevSignal — Main Pipeline","active":false,"activeVersionId":null,"isArchived":false,"createdAt":"2026-04-24T14:28:48.417Z","updatedAt":"2026-04-24T14:28:48.417Z","nodes":[{"parameters":{"notice":"","rule":{"interval":[{"field":"hours","hoursInterval":12,"triggerAtMinute":0}]}},"id":"b38e6f47-0ed0-45d9-a630-e43103d9b9a4","name":"Every 12 Hours","type":"n8n-nodes-base.scheduleTrigger","typeVersion":1.2,"position":[-480,128]},{"parameters":{"curlImport":"","method":"POST","url":"http://host.docker.internal:8000/run-pipeline","authentication":"none","provideSslCertificates":false,"sendQuery":false,"sendHeaders":true,"specifyHeaders":"keypair","headerParameters":{"parameters":[{"name":"X-Api-Key","value":"devsignal-local-key-2024"}]},"sendBody":false,"options":{"response":{"response":{"fullResponse":true,"neverError":false,"responseFormat":"autodetect"}},"timeout":1800000},"infoMessage":""},"id":"9616ca6d-5bb5-4253-a71f-8b0ce2579597","name":"Trigger Pipeline","type":"n8n-nodes-base.httpRequest","typeVersion":4.2,"position":[-240,128],"onError":"continueErrorOutput"},{"parameters":{"mode":"runOnceForAllItems","language":"javaScript","jsCode":"const response = $input.first().json;\\nconst body = response.body || response;\\nconsole.log('Pipeline status:', body.status);\\nconsole.log('Preview:', (body.preview || '').slice(-300));\\nreturn [{ json: { status: 'success', data: body } }];","notice":""},"id":"e8edd62b-4643-469c-9e33-08d99f49cbd6","name":"Log Success","type":"n8n-nodes-base.code","typeVersion":2,"position":[0,0]},{"parameters":{"mode":"runOnceForAllItems","language":"javaScript","jsCode":"const error = $input.first().json;\\nconst detail = error.error?.detail || error.message || 'Unknown error';\\nconst msg = typeof detail === 'object' ? JSON.stringify(detail) : String(detail);\\nconsole.error('Pipeline failed:', msg.slice(0, 500));\\nreturn [{ json: { status: 'failed', error_message: msg.slice(0, 1000) } }];","notice":""},"id":"c35065a3-6aa5-4045-be9b-09be07881794","name":"Parse Error","type":"n8n-nodes-base.code","typeVersion":2,"position":[0,240]},{"parameters":{"curlImport":"","method":"POST","url":"=https://api.telegram.org/bot{{ $env.TELEGRAM_BOT_TOKEN }}/sendMessage","authentication":"none","provideSslCertificates":false,"sendQuery":false,"sendHeaders":false,"sendBody":true,"contentType":"json","specifyBody":"keypair","bodyParameters":{"parameters":[{"name":"","value":""}]},"options":{},"infoMessage":""},"id":"8e6ca49a-ea77-4b21-921b-c447b52a6954","name":"Telegram Error Alert","type":"n8n-nodes-base.httpRequest","typeVersion":4.2,"position":[240,240]}],"connections":{"Every 12 Hours":{"main":[[{"node":"Trigger Pipeline","type":"main","index":0}]]},"Trigger Pipeline":{"main":[[{"node":"Log Success","type":"main","index":0}],[{"node":"Parse Error","type":"main","index":0}]]},"Parse Error":{"main":[[{"node":"Telegram Error Alert","type":"main","index":0}]]}},"settings":{"executionOrder":"v1","binaryMode":"separate"},"staticData":{"node:Every 12 Hours":{"recurrenceRules":[2]}},"pinData":{}}	[{"version":1,"startData":"1","resultData":"2","executionData":"3","resumeToken":"4"},{},{"runData":"5","pinData":"6","lastNodeExecuted":"7"},{"contextData":"8","nodeExecutionStack":"9","metadata":"10","waitingExecution":"11","waitingExecutionSource":"12","runtimeData":"13"},"b89e21379cae865ab78b52e642ca755f8e66ff5815ddde0c448edaf1582b3e41",{"Every 12 Hours":"14","Trigger Pipeline":"15","Log Success":"16"},{},"Log Success",{"node:Trigger Pipeline":"17"},[],{},{},{},{"version":1,"establishedAt":1777827094954,"source":"18","redaction":"19","triggerNode":"20"},["21"],["22"],["23"],{"response":"24"},"manual",{"version":1,"policy":"25"},{"name":"26","type":"27"},{"startTime":1777827094960,"executionIndex":0,"source":"28","hints":"29","executionTime":1,"executionStatus":"30","data":"31"},{"startTime":1777827094961,"executionIndex":1,"source":"32","hints":"33","executionTime":19,"executionStatus":"30","data":"34"},{"startTime":1777827094980,"executionIndex":2,"source":"35","hints":"36","executionTime":8,"executionStatus":"30","data":"37"},{"body":"38","headers":"39","statusCode":200,"statusMessage":"40"},"none","Every 12 Hours","n8n-nodes-base.scheduleTrigger",[],[],"success",{"main":"41"},["42"],[],{"main":"43"},["44"],[],{"main":"45"},{"status":"46","pid":56313,"message":"47"},{"date":"48","server":"49","content-length":"50","content-type":"51","connection":"52"},"OK",["53"],{"previousNode":"26","previousNodeOutput":0,"previousNodeRun":0},["54","55"],{"previousNode":"56","previousNodeOutput":0,"previousNodeRun":0},["57"],"started","Pipeline triggered successfully","Sun, 03 May 2026 16:51:33 GMT","uvicorn","76","application/json","close",["58"],["59"],[],"Trigger Pipeline",["60"],{"json":"61","pairedItem":"62"},{"json":"63","pairedItem":"64"},{"json":"65","pairedItem":"66"},{"timestamp":"67","Readable date":"68","Readable time":"69","Day of week":"70","Year":"71","Month":"72","Day of month":"73","Hour":"74","Minute":"75","Second":"76","Timezone":"77"},{"item":0},{"body":"38","headers":"39","statusCode":200,"statusMessage":"40"},{"item":0},{"status":"30","data":"78"},{"item":0},"2026-05-03T22:21:34.960+05:30","May 3rd 2026, 10:21:34 pm","10:21:34 pm","Sunday","2026","May","03","22","21","34","Asia/Kolkata (UTC+05:30)",{"status":"46","pid":56313,"message":"47"}]	5a0a6977-9d22-4843-8ac9-8a83b8c0ec97
10	{"id":"AlrynH2aZBv1h5NT","name":"DevSignal — Main Pipeline","active":false,"activeVersionId":null,"isArchived":false,"createdAt":"2026-04-24T14:28:48.417Z","updatedAt":"2026-04-24T14:28:48.417Z","nodes":[{"parameters":{"notice":"","rule":{"interval":[{"field":"hours","hoursInterval":12,"triggerAtMinute":0}]}},"id":"b38e6f47-0ed0-45d9-a630-e43103d9b9a4","name":"Every 12 Hours","type":"n8n-nodes-base.scheduleTrigger","typeVersion":1.2,"position":[-480,128]},{"parameters":{"curlImport":"","method":"POST","url":"http://host.docker.internal:8000/run-pipeline","authentication":"none","provideSslCertificates":false,"sendQuery":false,"sendHeaders":true,"specifyHeaders":"keypair","headerParameters":{"parameters":[{"name":"X-Api-Key","value":"devsignal-local-key-2024"}]},"sendBody":false,"options":{"response":{"response":{"fullResponse":true,"neverError":false,"responseFormat":"autodetect"}},"timeout":1800000},"infoMessage":""},"id":"9616ca6d-5bb5-4253-a71f-8b0ce2579597","name":"Trigger Pipeline","type":"n8n-nodes-base.httpRequest","typeVersion":4.2,"position":[-240,128],"onError":"continueErrorOutput"},{"parameters":{"mode":"runOnceForAllItems","language":"javaScript","jsCode":"const response = $input.first().json;\\nconst body = response.body || response;\\nconsole.log('Pipeline status:', body.status);\\nconsole.log('Preview:', (body.preview || '').slice(-300));\\nreturn [{ json: { status: 'success', data: body } }];","notice":""},"id":"e8edd62b-4643-469c-9e33-08d99f49cbd6","name":"Log Success","type":"n8n-nodes-base.code","typeVersion":2,"position":[0,0]},{"parameters":{"mode":"runOnceForAllItems","language":"javaScript","jsCode":"const error = $input.first().json;\\nconst detail = error.error?.detail || error.message || 'Unknown error';\\nconst msg = typeof detail === 'object' ? JSON.stringify(detail) : String(detail);\\nconsole.error('Pipeline failed:', msg.slice(0, 500));\\nreturn [{ json: { status: 'failed', error_message: msg.slice(0, 1000) } }];","notice":""},"id":"c35065a3-6aa5-4045-be9b-09be07881794","name":"Parse Error","type":"n8n-nodes-base.code","typeVersion":2,"position":[0,240]},{"parameters":{"curlImport":"","method":"POST","url":"=https://api.telegram.org/bot{{ $env.TELEGRAM_BOT_TOKEN }}/sendMessage","authentication":"none","provideSslCertificates":false,"sendQuery":false,"sendHeaders":false,"sendBody":true,"contentType":"json","specifyBody":"keypair","bodyParameters":{"parameters":[{"name":"","value":""}]},"options":{},"infoMessage":""},"id":"8e6ca49a-ea77-4b21-921b-c447b52a6954","name":"Telegram Error Alert","type":"n8n-nodes-base.httpRequest","typeVersion":4.2,"position":[240,240]}],"connections":{"Every 12 Hours":{"main":[[{"node":"Trigger Pipeline","type":"main","index":0}]]},"Trigger Pipeline":{"main":[[{"node":"Log Success","type":"main","index":0}],[{"node":"Parse Error","type":"main","index":0}]]},"Parse Error":{"main":[[{"node":"Telegram Error Alert","type":"main","index":0}]]}},"settings":{"executionOrder":"v1","binaryMode":"separate"},"staticData":{"node:Every 12 Hours":{"recurrenceRules":[2]}},"pinData":{}}	[{"version":1,"startData":"1","resultData":"2","executionData":"3","resumeToken":"4"},{},{"error":"5","runData":"6","pinData":"7","lastNodeExecuted":"8"},{"contextData":"9","nodeExecutionStack":"10","metadata":"11","waitingExecution":"12","waitingExecutionSource":"13","runtimeData":"14"},"65f2f8c3c9c6e991fd965d5af6a32110208683f921a2af182b296f15ca7a3600",{"cause":"15","level":"16","tags":"17","timestamp":1777966664570,"context":"18","functionality":"19","name":"20","message":"21","stack":"22"},{"Every 12 Hours":"23","Trigger Pipeline":"24","Parse Error":"25","Telegram Error Alert":"26"},{},"Telegram Error Alert",{},["27"],{},{},{},{"version":1,"establishedAt":1777965138465,"source":"28","redaction":"29","triggerNode":"30"},"=https://api.telegram.org/bot{{ $env.TELEGRAM_BOT_TOKEN }}/sendMessage","warning",{},{"causeDetailed":"31","runIndex":0,"itemIndex":0,"parameter":"32"},"regular","ExpressionError","access to env vars denied","ExpressionError: access to env vars denied\\n    at Object.get (/usr/local/lib/node_modules/n8n/node_modules/.pnpm/n8n-workflow@file+packages+workflow/node_modules/n8n-workflow/src/workflow-data-proxy-env-provider.ts:63:12)\\n    at Proxy.eval (eval at getFunction (/usr/local/lib/node_modules/n8n/node_modules/.pnpm/@n8n+tournament@1.0.6/node_modules/@n8n/tournament/src/FunctionEvaluator.ts:13:16), <anonymous>:7:51)\\n    at Proxy.eval (eval at getFunction (/usr/local/lib/node_modules/n8n/node_modules/.pnpm/@n8n+tournament@1.0.6/node_modules/@n8n/tournament/src/FunctionEvaluator.ts:13:16), <anonymous>:14:3)\\n    at FunctionEvaluator.evaluate (/usr/local/lib/node_modules/n8n/node_modules/.pnpm/@n8n+tournament@1.0.6/node_modules/@n8n/tournament/src/FunctionEvaluator.ts:20:13)\\n    at Tournament.execute (/usr/local/lib/node_modules/n8n/node_modules/.pnpm/@n8n+tournament@1.0.6/node_modules/@n8n/tournament/src/index.ts:45:25)\\n    at evaluateExpression (/usr/local/lib/node_modules/n8n/node_modules/.pnpm/n8n-workflow@file+packages+workflow/node_modules/n8n-workflow/src/expression-evaluator-proxy.ts:20:9)\\n    at Expression.renderExpression (/usr/local/lib/node_modules/n8n/node_modules/.pnpm/n8n-workflow@file+packages+workflow/node_modules/n8n-workflow/src/expression.ts:602:29)\\n    at Expression.resolveSimpleParameterValue (/usr/local/lib/node_modules/n8n/node_modules/.pnpm/n8n-workflow@file+packages+workflow/node_modules/n8n-workflow/src/expression.ts:564:28)\\n    at WorkflowExpression.resolveSimpleParameterValue (/usr/local/lib/node_modules/n8n/node_modules/.pnpm/n8n-workflow@file+packages+workflow/node_modules/n8n-workflow/src/workflow-expression.ts:66:26)\\n    at WorkflowExpression.getParameterValue (/usr/local/lib/node_modules/n8n/node_modules/.pnpm/n8n-workflow@file+packages+workflow/node_modules/n8n-workflow/src/workflow-expression.ts:134:16)",["33"],["34"],["35"],["36"],{"node":"37","data":"38","source":"39"},"manual",{"version":1,"policy":"40"},{"name":"41","type":"42"},"If you need access please contact the administrator to remove the environment variable ‘N8N_BLOCK_ENV_ACCESS_IN_NODE‘","url",{"startTime":1777965138475,"executionIndex":0,"source":"43","hints":"44","executionTime":6,"executionStatus":"45","data":"46"},{"startTime":1777965138482,"executionIndex":1,"source":"47","hints":"48","executionTime":1525995,"executionStatus":"45","data":"49"},{"startTime":1777966664482,"executionIndex":2,"source":"50","hints":"51","executionTime":57,"executionStatus":"45","data":"52"},{"startTime":1777966664540,"executionIndex":3,"source":"53","hints":"54","executionTime":46,"executionStatus":"55","error":"56"},{"parameters":"57","id":"58","name":"8","type":"59","typeVersion":4.2,"position":"60"},{"main":"61"},{"main":"53"},"none","Every 12 Hours","n8n-nodes-base.scheduleTrigger",[],[],"success",{"main":"62"},["63"],[],{"main":"64"},["65"],[],{"main":"66"},["67"],[],"error",{"cause":"15","level":"16","tags":"17","timestamp":1777966664570,"context":"18","functionality":"19","name":"20","message":"21","stack":"22"},{"curlImport":"68","method":"69","url":"15","authentication":"40","provideSslCertificates":false,"sendQuery":false,"sendHeaders":false,"sendBody":true,"contentType":"70","specifyBody":"71","bodyParameters":"72","options":"73","infoMessage":"68"},"8e6ca49a-ea77-4b21-921b-c447b52a6954","n8n-nodes-base.httpRequest",[240,240],["74"],["75"],{"previousNode":"41","previousNodeOutput":0,"previousNodeRun":0},["76","77"],{"previousNode":"78","previousNodeOutput":1,"previousNodeRun":0},["79"],{"previousNode":"80","previousNodeOutput":0,"previousNodeRun":0},"","POST","json","keypair",{"parameters":"81"},{},["82"],["83"],[],["84"],"Trigger Pipeline",["85"],"Parse Error",["86"],{"json":"87","pairedItem":"88"},{"json":"89","pairedItem":"90"},{"json":"91","pairedItem":"92"},{"json":"87","pairedItem":"93"},{"name":"68","value":"68"},{"status":"94","error_message":"95"},{"item":0},{"timestamp":"96","Readable date":"97","Readable time":"98","Day of week":"99","Year":"100","Month":"101","Day of month":"102","Hour":"103","Minute":"104","Second":"105","Timezone":"106"},{"item":0},{"timestamp":"96","Readable date":"97","Readable time":"98","Day of week":"99","Year":"100","Month":"101","Day of month":"102","Hour":"103","Minute":"104","Second":"105","Timezone":"106","error":"107"},{"item":0},{"item":0},"failed","Unknown error","2026-05-05T12:42:18.479+05:30","May 5th 2026, 12:42:18 pm","12:42:18 pm","Tuesday","2026","May","05","12","42","18","Asia/Kolkata (UTC+05:30)",{"message":"108","name":"109","stack":"110","code":"111"},"socket hang up","Error","Error: socket hang up\\n    at AxiosError.from (/usr/local/lib/node_modules/n8n/node_modules/.pnpm/axios@1.15.0/node_modules/axios/lib/core/AxiosError.js:7:24)\\n    at RedirectableRequest.handleRequestError (/usr/local/lib/node_modules/n8n/node_modules/.pnpm/axios@1.15.0/node_modules/axios/lib/adapters/http.js:871:27)\\n    at RedirectableRequest.emit (node:events:520:35)\\n    at ClientRequest.eventHandlers.<computed> (/usr/local/lib/node_modules/n8n/node_modules/.pnpm/follow-redirects@1.15.11/node_modules/follow-redirects/index.js:49:24)\\n    at ClientRequest.emit (node:events:508:28)\\n    at emitErrorEvent (node:_http_client:108:11)\\n    at Socket.socketOnEnd (node:_http_client:599:5)\\n    at Socket.emit (node:events:520:35)\\n    at endReadableNT (node:internal/streams/readable:1729:12)\\n    at processTicksAndRejections (node:internal/process/task_queues:90:21)\\n    at Axios.request (/usr/local/lib/node_modules/n8n/node_modules/.pnpm/axios@1.15.0/node_modules/axios/lib/core/Axios.js:46:41)\\n    at processTicksAndRejections (node:internal/process/task_queues:104:5)\\n    at invokeAxios (/usr/local/lib/node_modules/n8n/node_modules/.pnpm/n8n-core@file+packages+core_@opentelemetry+api@1.9.0_@opentelemetry+exporter-trace-otlp_2d19a9be2839cb42cd2e8c9cacd05d5a/node_modules/n8n-core/src/execution-engine/node-execution-context/utils/request-helper-functions.ts:95:10)\\n    at proxyRequestToAxios (/usr/local/lib/node_modules/n8n/node_modules/.pnpm/n8n-core@file+packages+core_@opentelemetry+api@1.9.0_@opentelemetry+exporter-trace-otlp_2d19a9be2839cb42cd2e8c9cacd05d5a/node_modules/n8n-core/src/execution-engine/node-execution-context/utils/request-helper-functions.ts:439:20)\\n    at Object.request (/usr/local/lib/node_modules/n8n/node_modules/.pnpm/n8n-core@file+packages+core_@opentelemetry+api@1.9.0_@opentelemetry+exporter-trace-otlp_2d19a9be2839cb42cd2e8c9cacd05d5a/node_modules/n8n-core/src/execution-engine/node-execution-context/utils/request-helper-functions.ts:1557:4)","ECONNRESET"]	5a0a6977-9d22-4843-8ac9-8a83b8c0ec97
11	{"id":"AlrynH2aZBv1h5NT","name":"DevSignal — Main Pipeline","active":false,"activeVersionId":null,"isArchived":false,"createdAt":"2026-04-24T14:28:48.417Z","updatedAt":"2026-05-05T07:59:13.763Z","nodes":[{"parameters":{"notice":"","rule":{"interval":[{"field":"hours","hoursInterval":12,"triggerAtMinute":0}]}},"id":"b38e6f47-0ed0-45d9-a630-e43103d9b9a4","name":"Every 12 Hours","type":"n8n-nodes-base.scheduleTrigger","typeVersion":1.2,"position":[-480,128]},{"parameters":{"curlImport":"","method":"POST","url":"http://host.docker.internal:8000/run-pipeline","authentication":"none","provideSslCertificates":false,"sendQuery":false,"sendHeaders":true,"specifyHeaders":"keypair","headerParameters":{"parameters":[{"name":"X-Api-Key","value":"devsignal-local-key-2024"}]},"sendBody":false,"options":{"response":{"response":{"fullResponse":true,"neverError":false,"responseFormat":"autodetect"}},"timeout":4000000},"infoMessage":""},"id":"9616ca6d-5bb5-4253-a71f-8b0ce2579597","name":"Trigger Pipeline","type":"n8n-nodes-base.httpRequest","typeVersion":4.2,"position":[-240,128],"onError":"continueErrorOutput"},{"parameters":{"mode":"runOnceForAllItems","language":"javaScript","jsCode":"const response = $input.first().json;\\nconst body = response.body || response;\\nconsole.log('Pipeline status:', body.status);\\nconsole.log('Preview:', (body.preview || '').slice(-300));\\nreturn [{ json: { status: 'success', data: body } }];","notice":""},"id":"e8edd62b-4643-469c-9e33-08d99f49cbd6","name":"Log Success","type":"n8n-nodes-base.code","typeVersion":2,"position":[0,0]},{"parameters":{"mode":"runOnceForAllItems","language":"javaScript","jsCode":"const error = $input.first().json;\\nconst detail = error.error?.detail || error.message || 'Unknown error';\\nconst msg = typeof detail === 'object' ? JSON.stringify(detail) : String(detail);\\nconsole.error('Pipeline failed:', msg.slice(0, 500));\\nreturn [{ json: { status: 'failed', error_message: msg.slice(0, 1000) } }];","notice":""},"id":"c35065a3-6aa5-4045-be9b-09be07881794","name":"Parse Error","type":"n8n-nodes-base.code","typeVersion":2,"position":[0,240]},{"parameters":{"curlImport":"","method":"POST","url":"=https://api.telegram.org/bot{{ $env.TELEGRAM_BOT_TOKEN }}/sendMessage","authentication":"none","provideSslCertificates":false,"sendQuery":false,"sendHeaders":false,"sendBody":true,"contentType":"json","specifyBody":"keypair","bodyParameters":{"parameters":[{"name":"","value":""}]},"options":{},"infoMessage":""},"id":"8e6ca49a-ea77-4b21-921b-c447b52a6954","name":"Telegram Error Alert","type":"n8n-nodes-base.httpRequest","typeVersion":4.2,"position":[240,240]}],"connections":{"Every 12 Hours":{"main":[[{"node":"Trigger Pipeline","type":"main","index":0}]]},"Trigger Pipeline":{"main":[[{"node":"Log Success","type":"main","index":0}],[{"node":"Parse Error","type":"main","index":0}]]},"Parse Error":{"main":[[{"node":"Telegram Error Alert","type":"main","index":0}]]}},"settings":{"executionOrder":"v1","binaryMode":"separate"},"staticData":{"node:Every 12 Hours":{"recurrenceRules":[2]}},"pinData":{}}	[{"version":1,"startData":"1","resultData":"2","executionData":"3","resumeToken":"4"},{"destinationNode":"5","runNodeFilter":"6"},{"runData":"7","pinData":"8","lastNodeExecuted":"9"},{"contextData":"10","nodeExecutionStack":"11","metadata":"12","waitingExecution":"13","waitingExecutionSource":"14","runtimeData":"15"},"3abb3c7d328899ba0b78c97e040aa5a819e379e66b7964d666bfe7029da21359",{"nodeName":"9","mode":"16"},["9"],{"Every 12 Hours":"17"},{},"Every 12 Hours",{},[],{},{},{},{"version":1,"establishedAt":1777977497888,"source":"18","redaction":"19","triggerNode":"20"},"inclusive",["21"],"manual",{"version":1,"policy":"22"},{"name":"9","type":"23"},{"startTime":1777977497894,"executionIndex":0,"source":"24","hints":"25","executionTime":4,"executionStatus":"26","data":"27"},"none","n8n-nodes-base.scheduleTrigger",[],[],"success",{"main":"28"},["29"],["30"],{"json":"31","pairedItem":"32"},{"timestamp":"33","Readable date":"34","Readable time":"35","Day of week":"36","Year":"37","Month":"38","Day of month":"39","Hour":"40","Minute":"41","Second":"42","Timezone":"43"},{"item":0},"2026-05-05T16:08:17.896+05:30","May 5th 2026, 4:08:17 pm","4:08:17 pm","Tuesday","2026","May","05","16","08","17","Asia/Kolkata (UTC+05:30)"]	c2fe07de-5bfc-470d-94ed-072de0da5de1
12	{"id":"AlrynH2aZBv1h5NT","name":"DevSignal — Main Pipeline","active":false,"activeVersionId":null,"isArchived":false,"createdAt":"2026-04-24T14:28:48.417Z","updatedAt":"2026-05-05T07:59:13.763Z","nodes":[{"parameters":{"notice":"","rule":{"interval":[{"field":"hours","hoursInterval":12,"triggerAtMinute":0}]}},"id":"b38e6f47-0ed0-45d9-a630-e43103d9b9a4","name":"Every 12 Hours","type":"n8n-nodes-base.scheduleTrigger","typeVersion":1.2,"position":[-480,128]},{"parameters":{"curlImport":"","method":"POST","url":"http://host.docker.internal:8000/run-pipeline","authentication":"none","provideSslCertificates":false,"sendQuery":false,"sendHeaders":true,"specifyHeaders":"keypair","headerParameters":{"parameters":[{"name":"X-Api-Key","value":"devsignal-local-key-2024"}]},"sendBody":false,"options":{"response":{"response":{"fullResponse":true,"neverError":false,"responseFormat":"autodetect"}},"timeout":4000000},"infoMessage":""},"id":"9616ca6d-5bb5-4253-a71f-8b0ce2579597","name":"Trigger Pipeline","type":"n8n-nodes-base.httpRequest","typeVersion":4.2,"position":[-240,128],"onError":"continueErrorOutput"},{"parameters":{"mode":"runOnceForAllItems","language":"javaScript","jsCode":"const response = $input.first().json;\\nconst body = response.body || response;\\nconsole.log('Pipeline status:', body.status);\\nconsole.log('Preview:', (body.preview || '').slice(-300));\\nreturn [{ json: { status: 'success', data: body } }];","notice":""},"id":"e8edd62b-4643-469c-9e33-08d99f49cbd6","name":"Log Success","type":"n8n-nodes-base.code","typeVersion":2,"position":[0,0]},{"parameters":{"mode":"runOnceForAllItems","language":"javaScript","jsCode":"const error = $input.first().json;\\nconst detail = error.error?.detail || error.message || 'Unknown error';\\nconst msg = typeof detail === 'object' ? JSON.stringify(detail) : String(detail);\\nconsole.error('Pipeline failed:', msg.slice(0, 500));\\nreturn [{ json: { status: 'failed', error_message: msg.slice(0, 1000) } }];","notice":""},"id":"c35065a3-6aa5-4045-be9b-09be07881794","name":"Parse Error","type":"n8n-nodes-base.code","typeVersion":2,"position":[0,240]},{"parameters":{"curlImport":"","method":"POST","url":"=https://api.telegram.org/bot{{ $env.TELEGRAM_BOT_TOKEN }}/sendMessage","authentication":"none","provideSslCertificates":false,"sendQuery":false,"sendHeaders":false,"sendBody":true,"contentType":"json","specifyBody":"keypair","bodyParameters":{"parameters":[{"name":"","value":""}]},"options":{},"infoMessage":""},"id":"8e6ca49a-ea77-4b21-921b-c447b52a6954","name":"Telegram Error Alert","type":"n8n-nodes-base.httpRequest","typeVersion":4.2,"position":[240,240]}],"connections":{"Every 12 Hours":{"main":[[{"node":"Trigger Pipeline","type":"main","index":0}]]},"Trigger Pipeline":{"main":[[{"node":"Log Success","type":"main","index":0}],[{"node":"Parse Error","type":"main","index":0}]]},"Parse Error":{"main":[[{"node":"Telegram Error Alert","type":"main","index":0}]]}},"settings":{"executionOrder":"v1","binaryMode":"separate"},"staticData":{"node:Every 12 Hours":{"recurrenceRules":[2]}},"pinData":{}}	[{"version":1,"startData":"1","resultData":"2","executionData":"3","resumeToken":"4"},{},{"runData":"5","pinData":"6","lastNodeExecuted":"7"},{"contextData":"8","nodeExecutionStack":"9","metadata":"10","waitingExecution":"11","waitingExecutionSource":"12","runtimeData":"13"},"bb66571561df5ede95bf988d7453a1600c1c2ac5c2b8e7b80976acd2becd20fa",{"Every 12 Hours":"14","Trigger Pipeline":"15","Log Success":"16"},{},"Log Success",{"node:Trigger Pipeline":"17"},[],{},{},{},{"version":1,"establishedAt":1777977503747,"source":"18","redaction":"19","triggerNode":"20"},["21"],["22"],["23"],{"response":"24"},"manual",{"version":1,"policy":"25"},{"name":"26","type":"27"},{"startTime":1777977503752,"executionIndex":0,"source":"28","hints":"29","executionTime":0,"executionStatus":"30","data":"31"},{"startTime":1777977503753,"executionIndex":1,"source":"32","hints":"33","executionTime":31,"executionStatus":"30","data":"34"},{"startTime":1777977503785,"executionIndex":2,"source":"35","hints":"36","executionTime":38,"executionStatus":"30","data":"37"},{"body":"38","headers":"39","statusCode":200,"statusMessage":"40"},"none","Every 12 Hours","n8n-nodes-base.scheduleTrigger",[],[],"success",{"main":"41"},["42"],[],{"main":"43"},["44"],[],{"main":"45"},{"status":"46","pid":30075,"message":"47"},{"date":"48","server":"49","content-length":"50","content-type":"51","connection":"52"},"OK",["53"],{"previousNode":"26","previousNodeOutput":0,"previousNodeRun":0},["54","55"],{"previousNode":"56","previousNodeOutput":0,"previousNodeRun":0},["57"],"started","Pipeline triggered successfully","Tue, 05 May 2026 10:38:23 GMT","uvicorn","76","application/json","close",["58"],["59"],[],"Trigger Pipeline",["60"],{"json":"61","pairedItem":"62"},{"json":"63","pairedItem":"64"},{"json":"65","pairedItem":"66"},{"timestamp":"67","Readable date":"68","Readable time":"69","Day of week":"70","Year":"71","Month":"72","Day of month":"73","Hour":"74","Minute":"75","Second":"76","Timezone":"77"},{"item":0},{"body":"38","headers":"39","statusCode":200,"statusMessage":"40"},{"item":0},{"status":"30","data":"78"},{"item":0},"2026-05-05T16:08:23.752+05:30","May 5th 2026, 4:08:23 pm","4:08:23 pm","Tuesday","2026","May","05","16","08","23","Asia/Kolkata (UTC+05:30)",{"status":"46","pid":30075,"message":"47"}]	c2fe07de-5bfc-470d-94ed-072de0da5de1
13	{"id":"AlrynH2aZBv1h5NT","name":"DevSignal — Main Pipeline","active":false,"activeVersionId":null,"isArchived":false,"createdAt":"2026-04-24T14:28:48.417Z","updatedAt":"2026-05-05T07:59:13.763Z","nodes":[{"parameters":{"notice":"","rule":{"interval":[{"field":"hours","hoursInterval":12,"triggerAtMinute":0}]}},"id":"b38e6f47-0ed0-45d9-a630-e43103d9b9a4","name":"Every 12 Hours","type":"n8n-nodes-base.scheduleTrigger","typeVersion":1.2,"position":[-480,128]},{"parameters":{"curlImport":"","method":"POST","url":"http://host.docker.internal:8000/run-pipeline","authentication":"none","provideSslCertificates":false,"sendQuery":false,"sendHeaders":true,"specifyHeaders":"keypair","headerParameters":{"parameters":[{"name":"X-Api-Key","value":"devsignal-local-key-2024"}]},"sendBody":false,"options":{"response":{"response":{"fullResponse":true,"neverError":false,"responseFormat":"autodetect"}},"timeout":4000000},"infoMessage":""},"id":"9616ca6d-5bb5-4253-a71f-8b0ce2579597","name":"Trigger Pipeline","type":"n8n-nodes-base.httpRequest","typeVersion":4.2,"position":[-240,128],"onError":"continueErrorOutput"},{"parameters":{"mode":"runOnceForAllItems","language":"javaScript","jsCode":"const response = $input.first().json;\\nconst body = response.body || response;\\nconsole.log('Pipeline status:', body.status);\\nconsole.log('Preview:', (body.preview || '').slice(-300));\\nreturn [{ json: { status: 'success', data: body } }];","notice":""},"id":"e8edd62b-4643-469c-9e33-08d99f49cbd6","name":"Log Success","type":"n8n-nodes-base.code","typeVersion":2,"position":[0,0]},{"parameters":{"mode":"runOnceForAllItems","language":"javaScript","jsCode":"const error = $input.first().json;\\nconst detail = error.error?.detail || error.message || 'Unknown error';\\nconst msg = typeof detail === 'object' ? JSON.stringify(detail) : String(detail);\\nconsole.error('Pipeline failed:', msg.slice(0, 500));\\nreturn [{ json: { status: 'failed', error_message: msg.slice(0, 1000) } }];","notice":""},"id":"c35065a3-6aa5-4045-be9b-09be07881794","name":"Parse Error","type":"n8n-nodes-base.code","typeVersion":2,"position":[0,240]},{"parameters":{"curlImport":"","method":"POST","url":"=https://api.telegram.org/bot{{ $env.TELEGRAM_BOT_TOKEN }}/sendMessage","authentication":"none","provideSslCertificates":false,"sendQuery":false,"sendHeaders":false,"sendBody":true,"contentType":"json","specifyBody":"keypair","bodyParameters":{"parameters":[{"name":"","value":""}]},"options":{},"infoMessage":""},"id":"8e6ca49a-ea77-4b21-921b-c447b52a6954","name":"Telegram Error Alert","type":"n8n-nodes-base.httpRequest","typeVersion":4.2,"position":[240,240]}],"connections":{"Every 12 Hours":{"main":[[{"node":"Trigger Pipeline","type":"main","index":0}]]},"Trigger Pipeline":{"main":[[{"node":"Log Success","type":"main","index":0}],[{"node":"Parse Error","type":"main","index":0}]]},"Parse Error":{"main":[[{"node":"Telegram Error Alert","type":"main","index":0}]]}},"settings":{"executionOrder":"v1","binaryMode":"separate"},"staticData":{"node:Every 12 Hours":{"recurrenceRules":[2]}},"pinData":{}}	[{"version":1,"startData":"1","resultData":"2","executionData":"3","resumeToken":"4"},{},{"runData":"5","pinData":"6","lastNodeExecuted":"7"},{"contextData":"8","nodeExecutionStack":"9","metadata":"10","waitingExecution":"11","waitingExecutionSource":"12","runtimeData":"13"},"16dc2d9af429d32939fa098ce710d6a75b17dea378e26b61bbffae5e4e69ea9f",{"Every 12 Hours":"14","Trigger Pipeline":"15","Log Success":"16"},{},"Log Success",{"node:Trigger Pipeline":"17"},[],{},{},{},{"version":1,"establishedAt":1777977546095,"source":"18","redaction":"19","triggerNode":"20"},["21"],["22"],["23"],{"response":"24"},"manual",{"version":1,"policy":"25"},{"name":"26","type":"27"},{"startTime":1777977546105,"executionIndex":0,"source":"28","hints":"29","executionTime":1,"executionStatus":"30","data":"31"},{"startTime":1777977546106,"executionIndex":1,"source":"32","hints":"33","executionTime":20,"executionStatus":"30","data":"34"},{"startTime":1777977546126,"executionIndex":2,"source":"35","hints":"36","executionTime":10,"executionStatus":"30","data":"37"},{"body":"38","headers":"39","statusCode":200,"statusMessage":"40"},"none","Every 12 Hours","n8n-nodes-base.scheduleTrigger",[],[],"success",{"main":"41"},["42"],[],{"main":"43"},["44"],[],{"main":"45"},{"status":"46","pid":30307,"message":"47"},{"date":"48","server":"49","content-length":"50","content-type":"51","connection":"52"},"OK",["53"],{"previousNode":"26","previousNodeOutput":0,"previousNodeRun":0},["54","55"],{"previousNode":"56","previousNodeOutput":0,"previousNodeRun":0},["57"],"started","Pipeline triggered successfully","Tue, 05 May 2026 10:39:05 GMT","uvicorn","76","application/json","close",["58"],["59"],[],"Trigger Pipeline",["60"],{"json":"61","pairedItem":"62"},{"json":"63","pairedItem":"64"},{"json":"65","pairedItem":"66"},{"timestamp":"67","Readable date":"68","Readable time":"69","Day of week":"70","Year":"71","Month":"72","Day of month":"73","Hour":"74","Minute":"75","Second":"76","Timezone":"77"},{"item":0},{"body":"38","headers":"39","statusCode":200,"statusMessage":"40"},{"item":0},{"status":"30","data":"78"},{"item":0},"2026-05-05T16:09:06.106+05:30","May 5th 2026, 4:09:06 pm","4:09:06 pm","Tuesday","2026","May","05","16","09","06","Asia/Kolkata (UTC+05:30)",{"status":"46","pid":30307,"message":"47"}]	c2fe07de-5bfc-470d-94ed-072de0da5de1
15	{"id":"AlrynH2aZBv1h5NT","name":"DevSignal — Main Pipeline","active":false,"activeVersionId":null,"isArchived":false,"createdAt":"2026-04-24T14:28:48.417Z","updatedAt":"2026-05-05T07:59:13.763Z","nodes":[{"parameters":{"notice":"","rule":{"interval":[{"field":"hours","hoursInterval":12,"triggerAtMinute":0}]}},"id":"b38e6f47-0ed0-45d9-a630-e43103d9b9a4","name":"Every 12 Hours","type":"n8n-nodes-base.scheduleTrigger","typeVersion":1.2,"position":[-480,128]},{"parameters":{"curlImport":"","method":"POST","url":"http://host.docker.internal:8000/run-pipeline","authentication":"none","provideSslCertificates":false,"sendQuery":false,"sendHeaders":true,"specifyHeaders":"keypair","headerParameters":{"parameters":[{"name":"X-Api-Key","value":"devsignal-local-key-2024"}]},"sendBody":false,"options":{"response":{"response":{"fullResponse":true,"neverError":false,"responseFormat":"autodetect"}},"timeout":4000000},"infoMessage":""},"id":"9616ca6d-5bb5-4253-a71f-8b0ce2579597","name":"Trigger Pipeline","type":"n8n-nodes-base.httpRequest","typeVersion":4.2,"position":[-240,128],"onError":"continueErrorOutput"},{"parameters":{"mode":"runOnceForAllItems","language":"javaScript","jsCode":"const response = $input.first().json;\\nconst body = response.body || response;\\nconsole.log('Pipeline status:', body.status);\\nconsole.log('Preview:', (body.preview || '').slice(-300));\\nreturn [{ json: { status: 'success', data: body } }];","notice":""},"id":"e8edd62b-4643-469c-9e33-08d99f49cbd6","name":"Log Success","type":"n8n-nodes-base.code","typeVersion":2,"position":[0,0]},{"parameters":{"mode":"runOnceForAllItems","language":"javaScript","jsCode":"const error = $input.first().json;\\nconst detail = error.error?.detail || error.message || 'Unknown error';\\nconst msg = typeof detail === 'object' ? JSON.stringify(detail) : String(detail);\\nconsole.error('Pipeline failed:', msg.slice(0, 500));\\nreturn [{ json: { status: 'failed', error_message: msg.slice(0, 1000) } }];","notice":""},"id":"c35065a3-6aa5-4045-be9b-09be07881794","name":"Parse Error","type":"n8n-nodes-base.code","typeVersion":2,"position":[0,240]},{"parameters":{"curlImport":"","method":"POST","url":"=https://api.telegram.org/bot{{ $env.TELEGRAM_BOT_TOKEN }}/sendMessage","authentication":"none","provideSslCertificates":false,"sendQuery":false,"sendHeaders":false,"sendBody":true,"contentType":"json","specifyBody":"keypair","bodyParameters":{"parameters":[{"name":"","value":""}]},"options":{},"infoMessage":""},"id":"8e6ca49a-ea77-4b21-921b-c447b52a6954","name":"Telegram Error Alert","type":"n8n-nodes-base.httpRequest","typeVersion":4.2,"position":[240,240]}],"connections":{"Every 12 Hours":{"main":[[{"node":"Trigger Pipeline","type":"main","index":0}]]},"Trigger Pipeline":{"main":[[{"node":"Log Success","type":"main","index":0}],[{"node":"Parse Error","type":"main","index":0}]]},"Parse Error":{"main":[[{"node":"Telegram Error Alert","type":"main","index":0}]]}},"settings":{"executionOrder":"v1","binaryMode":"separate"},"staticData":{"node:Every 12 Hours":{"recurrenceRules":[2]}},"pinData":{}}	[{"version":1,"startData":"1","resultData":"2","executionData":"3","resumeToken":"4"},{},{"runData":"5","pinData":"6","lastNodeExecuted":"7"},{"contextData":"8","nodeExecutionStack":"9","metadata":"10","waitingExecution":"11","waitingExecutionSource":"12","runtimeData":"13"},"9f93eda9d65d9a20de707ec4768ab30ff512245a723968526ff51c7593cf325a",{"Every 12 Hours":"14","Trigger Pipeline":"15","Log Success":"16"},{},"Log Success",{"node:Trigger Pipeline":"17"},[],{},{},{},{"version":1,"establishedAt":1777979067187,"source":"18","redaction":"19","triggerNode":"20"},["21"],["22"],["23"],{"response":"24"},"manual",{"version":1,"policy":"25"},{"name":"26","type":"27"},{"startTime":1777979067193,"executionIndex":0,"source":"28","hints":"29","executionTime":1,"executionStatus":"30","data":"31"},{"startTime":1777979067195,"executionIndex":1,"source":"32","hints":"33","executionTime":28,"executionStatus":"30","data":"34"},{"startTime":1777979067224,"executionIndex":2,"source":"35","hints":"36","executionTime":10,"executionStatus":"30","data":"37"},{"body":"38","headers":"39","statusCode":200,"statusMessage":"40"},"none","Every 12 Hours","n8n-nodes-base.scheduleTrigger",[],[],"success",{"main":"41"},["42"],[],{"main":"43"},["44"],[],{"main":"45"},{"status":"46","pid":41579,"message":"47"},{"date":"48","server":"49","content-length":"50","content-type":"51","connection":"52"},"OK",["53"],{"previousNode":"26","previousNodeOutput":0,"previousNodeRun":0},["54","55"],{"previousNode":"56","previousNodeOutput":0,"previousNodeRun":0},["57"],"started","Pipeline triggered successfully","Tue, 05 May 2026 11:04:27 GMT","uvicorn","76","application/json","close",["58"],["59"],[],"Trigger Pipeline",["60"],{"json":"61","pairedItem":"62"},{"json":"63","pairedItem":"64"},{"json":"65","pairedItem":"66"},{"timestamp":"67","Readable date":"68","Readable time":"69","Day of week":"70","Year":"71","Month":"72","Day of month":"73","Hour":"74","Minute":"75","Second":"76","Timezone":"77"},{"item":0},{"body":"38","headers":"39","statusCode":200,"statusMessage":"40"},{"item":0},{"status":"30","data":"78"},{"item":0},"2026-05-05T16:34:27.194+05:30","May 5th 2026, 4:34:27 pm","4:34:27 pm","Tuesday","2026","May","05","16","34","27","Asia/Kolkata (UTC+05:30)",{"status":"46","pid":41579,"message":"47"}]	c2fe07de-5bfc-470d-94ed-072de0da5de1
16	{"id":"AlrynH2aZBv1h5NT","name":"DevSignal — Main Pipeline","active":false,"activeVersionId":null,"isArchived":false,"createdAt":"2026-04-24T14:28:48.417Z","updatedAt":"2026-05-06T15:40:46.090Z","nodes":[{"parameters":{"notice":"","rule":{"interval":[{"field":"hours","hoursInterval":12,"triggerAtMinute":0}]}},"id":"b38e6f47-0ed0-45d9-a630-e43103d9b9a4","name":"Every 12 Hours","type":"n8n-nodes-base.scheduleTrigger","typeVersion":1.2,"position":[-480,128]},{"parameters":{"curlImport":"","method":"POST","url":"http://host.docker.internal:8000/run-pipeline","authentication":"none","provideSslCertificates":false,"sendQuery":false,"sendHeaders":true,"specifyHeaders":"keypair","headerParameters":{"parameters":[{"name":"X-Api-Key","value":"devsignal-local-key-2024"}]},"sendBody":false,"options":{"response":{"response":{"fullResponse":true,"neverError":false,"responseFormat":"autodetect"}},"timeout":4000000},"infoMessage":""},"id":"9616ca6d-5bb5-4253-a71f-8b0ce2579597","name":"Trigger Pipeline","type":"n8n-nodes-base.httpRequest","typeVersion":4.2,"position":[-240,128],"onError":"continueErrorOutput"},{"parameters":{"mode":"runOnceForAllItems","language":"javaScript","jsCode":"const response = $input.first().json;\\nconst body = response.body || response;\\nconsole.log('Pipeline status:', body.status);\\nconsole.log('Preview:', (body.preview || '').slice(-300));\\nreturn [{ json: { status: 'success', data: body } }];","notice":""},"id":"e8edd62b-4643-469c-9e33-08d99f49cbd6","name":"Log Success","type":"n8n-nodes-base.code","typeVersion":2,"position":[0,0]},{"parameters":{"mode":"runOnceForAllItems","language":"javaScript","jsCode":"const error = $input.first().json;\\nconst detail = error.error?.detail || error.message || 'Unknown error';\\nconst msg = typeof detail === 'object' ? JSON.stringify(detail) : String(detail);\\nconsole.error('Pipeline failed:', msg.slice(0, 500));\\nreturn [{ json: { status: 'failed', error_message: msg.slice(0, 1000) } }];","notice":""},"id":"c35065a3-6aa5-4045-be9b-09be07881794","name":"Parse Error","type":"n8n-nodes-base.code","typeVersion":2,"position":[0,240]},{"parameters":{"curlImport":"","method":"POST","url":"=https://api.telegram.org/bot{{ $env.TELEGRAM_BOT_TOKEN }}/sendMessage","authentication":"none","provideSslCertificates":false,"sendQuery":false,"sendHeaders":false,"sendBody":true,"contentType":"json","specifyBody":"keypair","bodyParameters":{"parameters":[{"name":"","value":""}]},"options":{},"infoMessage":""},"id":"8e6ca49a-ea77-4b21-921b-c447b52a6954","name":"Telegram Error Alert","type":"n8n-nodes-base.httpRequest","typeVersion":4.2,"position":[240,240]}],"connections":{"Every 12 Hours":{"main":[[{"node":"Trigger Pipeline","type":"main","index":0}]]},"Trigger Pipeline":{"main":[[{"node":"Log Success","type":"main","index":0}],[{"node":"Parse Error","type":"main","index":0}]]},"Parse Error":{"main":[[{"node":"Telegram Error Alert","type":"main","index":0}]]}},"settings":{"executionOrder":"v1","binaryMode":"separate"},"staticData":{"node:Every 12 Hours":{"recurrenceRules":[2]}},"pinData":{}}	[{"version":1,"startData":"1","resultData":"2","executionData":"3","resumeToken":"4"},{},{"runData":"5","pinData":"6","lastNodeExecuted":"7"},{"contextData":"8","nodeExecutionStack":"9","metadata":"10","waitingExecution":"11","waitingExecutionSource":"12","runtimeData":"13"},"59dcf5f76c825d19800a1d8fc0827e97f398bcd7b31d39abc45ada066d24fc01",{"Every 12 Hours":"14","Trigger Pipeline":"15","Log Success":"16"},{},"Log Success",{"node:Trigger Pipeline":"17"},[],{},{},{},{"version":1,"establishedAt":1778082061720,"source":"18","redaction":"19","triggerNode":"20"},["21"],["22"],["23"],{"response":"24"},"manual",{"version":1,"policy":"25"},{"name":"26","type":"27"},{"startTime":1778082061725,"executionIndex":0,"source":"28","hints":"29","executionTime":4,"executionStatus":"30","data":"31"},{"startTime":1778082061730,"executionIndex":1,"source":"32","hints":"33","executionTime":34,"executionStatus":"30","data":"34"},{"startTime":1778082061765,"executionIndex":2,"source":"35","hints":"36","executionTime":72,"executionStatus":"30","data":"37"},{"body":"38","headers":"39","statusCode":200,"statusMessage":"40"},"none","Every 12 Hours","n8n-nodes-base.scheduleTrigger",[],[],"success",{"main":"41"},["42"],[],{"main":"43"},["44"],[],{"main":"45"},{"status":"46","pid":20223,"message":"47"},{"date":"48","server":"49","content-length":"50","content-type":"51","connection":"52"},"OK",["53"],{"previousNode":"26","previousNodeOutput":0,"previousNodeRun":0},["54","55"],{"previousNode":"56","previousNodeOutput":0,"previousNodeRun":0},["57"],"started","Pipeline triggered successfully","Wed, 06 May 2026 15:41:01 GMT","uvicorn","76","application/json","close",["58"],["59"],[],"Trigger Pipeline",["60"],{"json":"61","pairedItem":"62"},{"json":"63","pairedItem":"64"},{"json":"65","pairedItem":"66"},{"timestamp":"67","Readable date":"68","Readable time":"69","Day of week":"70","Year":"71","Month":"72","Day of month":"73","Hour":"74","Minute":"75","Second":"76","Timezone":"77"},{"item":0},{"body":"38","headers":"39","statusCode":200,"statusMessage":"40"},{"item":0},{"status":"30","data":"78"},{"item":0},"2026-05-06T21:11:01.726+05:30","May 6th 2026, 9:11:01 pm","9:11:01 pm","Wednesday","2026","May","06","21","11","01","Asia/Kolkata (UTC+05:30)",{"status":"46","pid":20223,"message":"47"}]	c2fe07de-5bfc-470d-94ed-072de0da5de1
17	{"id":"CD2GddIS6pD1N23E","name":"My workflow","active":false,"activeVersionId":null,"isArchived":false,"createdAt":"2026-05-07T07:00:22.772Z","updatedAt":"2026-05-07T07:00:48.529Z","nodes":[{"parameters":{"notice":""},"type":"n8n-nodes-base.manualTrigger","typeVersion":1,"position":[0,0],"id":"ff5a732c-7d53-443e-adf0-53e433fc7a50","name":"When clicking ‘Execute workflow’"},{"parameters":{"curlImport":"","method":"GET","url":"http://host.docker.internal:8000/n8n-ping","authentication":"none","provideSslCertificates":false,"sendQuery":false,"sendHeaders":false,"sendBody":false,"options":{},"infoMessage":""},"type":"n8n-nodes-base.httpRequest","typeVersion":4.4,"position":[192,64],"id":"ae47912b-48d0-4628-80bb-e871690e57d9","name":"HTTP Request"}],"connections":{"When clicking ‘Execute workflow’":{"main":[[{"node":"HTTP Request","type":"main","index":0}]]}},"settings":{"executionOrder":"v1","binaryMode":"separate"},"staticData":null,"pinData":{}}	[{"version":1,"startData":"1","resultData":"2","executionData":"3","resumeToken":"4"},{"destinationNode":"5","runNodeFilter":"6"},{"error":"7","runData":"8","pinData":"9","lastNodeExecuted":"10"},{"contextData":"11","nodeExecutionStack":"12","metadata":"13","waitingExecution":"14","waitingExecutionSource":"15","runtimeData":"16"},"8fabb0ccb462c8db6677f19971ff9269f2f871e8d20f8a556f4cbedb9e8df3bb",{"nodeName":"10","mode":"17"},["18","10"],{"level":"19","tags":"20","description":"21","timestamp":1778137260115,"context":"22","functionality":"23","name":"24","node":"25","messages":"26","httpCode":"27","message":"28","stack":"29"},{"When clicking ‘Execute workflow’":"30","HTTP Request":"31"},{},"HTTP Request",{},["32"],{},{},{},{"version":1,"establishedAt":1778137259865,"source":"33","redaction":"34","triggerNode":"35"},"inclusive","When clicking ‘Execute workflow’","warning",{},"Internal Server Error",{"itemIndex":0,"request":"36"},"regular","NodeApiError",{"parameters":"37","type":"38","typeVersion":4.4,"position":"39","id":"40","name":"10"},["41"],"500","The service was not able to process your request","NodeApiError: The service was not able to process your request\\n    at ExecuteContext.execute (/usr/local/lib/node_modules/n8n/node_modules/.pnpm/n8n-nodes-base@file+packages+nodes-base_@aws-sdk+credential-providers@3.808.0_asn1.js@5_8da18263ca0574b0db58d4fefd8173ce/node_modules/n8n-nodes-base/nodes/HttpRequest/V3/HttpRequestV3.node.ts:816:16)\\n    at processTicksAndRejections (node:internal/process/task_queues:104:5)\\n    at WorkflowExecute.executeNode (/usr/local/lib/node_modules/n8n/node_modules/.pnpm/n8n-core@file+packages+core_@opentelemetry+api@1.9.0_@opentelemetry+exporter-trace-otlp_2d19a9be2839cb42cd2e8c9cacd05d5a/node_modules/n8n-core/src/execution-engine/workflow-execute.ts:1045:8)\\n    at WorkflowExecute.runNode (/usr/local/lib/node_modules/n8n/node_modules/.pnpm/n8n-core@file+packages+core_@opentelemetry+api@1.9.0_@opentelemetry+exporter-trace-otlp_2d19a9be2839cb42cd2e8c9cacd05d5a/node_modules/n8n-core/src/execution-engine/workflow-execute.ts:1224:11)\\n    at /usr/local/lib/node_modules/n8n/node_modules/.pnpm/n8n-core@file+packages+core_@opentelemetry+api@1.9.0_@opentelemetry+exporter-trace-otlp_2d19a9be2839cb42cd2e8c9cacd05d5a/node_modules/n8n-core/src/execution-engine/workflow-execute.ts:1672:27\\n    at /usr/local/lib/node_modules/n8n/node_modules/.pnpm/n8n-core@file+packages+core_@opentelemetry+api@1.9.0_@opentelemetry+exporter-trace-otlp_2d19a9be2839cb42cd2e8c9cacd05d5a/node_modules/n8n-core/src/execution-engine/workflow-execute.ts:2324:11",["42"],["43"],{"node":"44","data":"45","source":"46"},"manual",{"version":1,"policy":"47"},{"name":"18","type":"48"},{"headers":"49","method":"50","uri":"51","gzip":true,"rejectUnauthorized":true,"followRedirect":true,"resolveWithFullResponse":true,"sendCredentialsOnCrossOriginRedirect":false,"followAllRedirects":true,"timeout":300000,"encoding":null,"json":false,"useStream":true},{"curlImport":"52","method":"50","url":"51","authentication":"47","provideSslCertificates":false,"sendQuery":false,"sendHeaders":false,"sendBody":false,"options":"53","infoMessage":"52"},"n8n-nodes-base.httpRequest",[192,64],"ae47912b-48d0-4628-80bb-e871690e57d9","500 - \\"Internal Server Error\\"",{"startTime":1778137259871,"executionIndex":0,"source":"54","hints":"55","executionTime":1,"executionStatus":"56","data":"57"},{"startTime":1778137259874,"executionIndex":1,"source":"58","hints":"59","executionTime":252,"executionStatus":"60","error":"61"},{"parameters":"62","type":"38","typeVersion":4.4,"position":"63","id":"40","name":"10"},{"main":"64"},{"main":"58"},"none","n8n-nodes-base.manualTrigger",{"accept":"65"},"GET","http://host.docker.internal:8000/n8n-ping","",{},[],[],"success",{"main":"66"},["67"],[],"error",{"level":"19","tags":"20","description":"21","timestamp":1778137260115,"context":"22","functionality":"23","name":"24","node":"25","messages":"26","httpCode":"27","message":"28","stack":"29"},{"curlImport":"52","method":"50","url":"51","authentication":"47","provideSslCertificates":false,"sendQuery":false,"sendHeaders":false,"sendBody":false,"options":"68","infoMessage":"52"},[192,64],["69"],"application/json,text/html,application/xhtml+xml,application/xml,text/*;q=0.9, image/*;q=0.8, */*;q=0.7",["70"],{"previousNode":"18","previousNodeOutput":0,"previousNodeRun":0},{},["71"],["72"],{"json":"73","pairedItem":"74"},{"json":"73","pairedItem":"75"},{},{"item":0},{"item":0}]	785c1aca-de59-46db-a102-7e5a9a6fb0cc
18	{"id":"CD2GddIS6pD1N23E","name":"My workflow","active":false,"activeVersionId":null,"isArchived":false,"createdAt":"2026-05-07T07:00:22.772Z","updatedAt":"2026-05-07T07:00:48.529Z","nodes":[{"parameters":{"notice":""},"type":"n8n-nodes-base.manualTrigger","typeVersion":1,"position":[0,0],"id":"ff5a732c-7d53-443e-adf0-53e433fc7a50","name":"When clicking ‘Execute workflow’"},{"parameters":{"curlImport":"","method":"GET","url":"http://host.docker.internal:8000/n8n-ping","authentication":"none","provideSslCertificates":false,"sendQuery":false,"sendHeaders":false,"sendBody":false,"options":{},"infoMessage":""},"type":"n8n-nodes-base.httpRequest","typeVersion":4.4,"position":[192,64],"id":"ae47912b-48d0-4628-80bb-e871690e57d9","name":"HTTP Request"}],"connections":{"When clicking ‘Execute workflow’":{"main":[[{"node":"HTTP Request","type":"main","index":0}]]}},"settings":{"executionOrder":"v1","binaryMode":"separate"},"staticData":null,"pinData":{}}	[{"version":1,"startData":"1","resultData":"2","executionData":"3","resumeToken":"4"},{"destinationNode":"5","runNodeFilter":"6"},{"error":"7","runData":"8","pinData":"9","lastNodeExecuted":"10"},{"contextData":"11","nodeExecutionStack":"12","metadata":"13","waitingExecution":"14","waitingExecutionSource":"15","runtimeData":"16"},"c1d63627cecd65f40ba5d111c3996d9259817547b05c7ec0a944f9c6f5f0bccf",{"nodeName":"10","mode":"17"},["18","10"],{"level":"19","tags":"20","description":"21","timestamp":1778137290811,"context":"22","functionality":"23","name":"24","node":"25","messages":"26","httpCode":"27","message":"28","stack":"29"},{"When clicking ‘Execute workflow’":"30","HTTP Request":"31"},{},"HTTP Request",{},["32"],{},{},{},{"version":1,"establishedAt":1778137290783,"source":"33","redaction":"34","triggerNode":"35"},"inclusive","When clicking ‘Execute workflow’","warning",{},"Internal Server Error",{"itemIndex":0,"request":"36"},"regular","NodeApiError",{"parameters":"37","type":"38","typeVersion":4.4,"position":"39","id":"40","name":"10"},["41"],"500","The service was not able to process your request","NodeApiError: The service was not able to process your request\\n    at ExecuteContext.execute (/usr/local/lib/node_modules/n8n/node_modules/.pnpm/n8n-nodes-base@file+packages+nodes-base_@aws-sdk+credential-providers@3.808.0_asn1.js@5_8da18263ca0574b0db58d4fefd8173ce/node_modules/n8n-nodes-base/nodes/HttpRequest/V3/HttpRequestV3.node.ts:816:16)\\n    at processTicksAndRejections (node:internal/process/task_queues:104:5)\\n    at WorkflowExecute.executeNode (/usr/local/lib/node_modules/n8n/node_modules/.pnpm/n8n-core@file+packages+core_@opentelemetry+api@1.9.0_@opentelemetry+exporter-trace-otlp_2d19a9be2839cb42cd2e8c9cacd05d5a/node_modules/n8n-core/src/execution-engine/workflow-execute.ts:1045:8)\\n    at WorkflowExecute.runNode (/usr/local/lib/node_modules/n8n/node_modules/.pnpm/n8n-core@file+packages+core_@opentelemetry+api@1.9.0_@opentelemetry+exporter-trace-otlp_2d19a9be2839cb42cd2e8c9cacd05d5a/node_modules/n8n-core/src/execution-engine/workflow-execute.ts:1224:11)\\n    at /usr/local/lib/node_modules/n8n/node_modules/.pnpm/n8n-core@file+packages+core_@opentelemetry+api@1.9.0_@opentelemetry+exporter-trace-otlp_2d19a9be2839cb42cd2e8c9cacd05d5a/node_modules/n8n-core/src/execution-engine/workflow-execute.ts:1672:27\\n    at /usr/local/lib/node_modules/n8n/node_modules/.pnpm/n8n-core@file+packages+core_@opentelemetry+api@1.9.0_@opentelemetry+exporter-trace-otlp_2d19a9be2839cb42cd2e8c9cacd05d5a/node_modules/n8n-core/src/execution-engine/workflow-execute.ts:2324:11",["42"],["43"],{"node":"44","data":"45","source":"46"},"manual",{"version":1,"policy":"47"},{"name":"10","type":"38"},{"headers":"48","method":"49","uri":"50","gzip":true,"rejectUnauthorized":true,"followRedirect":true,"resolveWithFullResponse":true,"sendCredentialsOnCrossOriginRedirect":false,"followAllRedirects":true,"timeout":300000,"encoding":null,"json":false,"useStream":true},{"curlImport":"51","method":"49","url":"50","authentication":"47","provideSslCertificates":false,"sendQuery":false,"sendHeaders":false,"sendBody":false,"options":"52","infoMessage":"51"},"n8n-nodes-base.httpRequest",[192,64],"ae47912b-48d0-4628-80bb-e871690e57d9","500 - \\"Internal Server Error\\"",{"startTime":1778137259871,"executionIndex":0,"source":"53","hints":"54","executionTime":1,"executionStatus":"55","data":"56"},{"startTime":1778137290788,"executionIndex":1,"source":"57","hints":"58","executionTime":23,"executionStatus":"59","error":"60"},{"parameters":"61","type":"38","typeVersion":4.4,"position":"62","id":"40","name":"10"},{"main":"63"},{"main":"57"},"none",{"accept":"64"},"GET","http://host.docker.internal:8000/n8n-ping","",{},[],[],"success",{"main":"65"},["66"],[],"error",{"level":"19","tags":"20","description":"21","timestamp":1778137290811,"context":"22","functionality":"23","name":"24","node":"25","messages":"26","httpCode":"27","message":"28","stack":"29"},{"curlImport":"51","method":"49","url":"50","authentication":"47","provideSslCertificates":false,"sendQuery":false,"sendHeaders":false,"sendBody":false,"options":"67","infoMessage":"51"},[192,64],["68"],"application/json,text/html,application/xhtml+xml,application/xml,text/*;q=0.9, image/*;q=0.8, */*;q=0.7",["69"],{"previousNode":"18","previousNodeOutput":0,"previousNodeRun":0},{},["70"],["71"],{"json":"72","pairedItem":"73"},{"json":"72","pairedItem":"74"},{},{"item":0},{"item":0}]	785c1aca-de59-46db-a102-7e5a9a6fb0cc
19	{"id":"CD2GddIS6pD1N23E","name":"My workflow","active":false,"activeVersionId":null,"isArchived":false,"createdAt":"2026-05-07T07:00:22.772Z","updatedAt":"2026-05-07T07:00:48.529Z","nodes":[{"parameters":{"notice":""},"type":"n8n-nodes-base.manualTrigger","typeVersion":1,"position":[0,0],"id":"ff5a732c-7d53-443e-adf0-53e433fc7a50","name":"When clicking ‘Execute workflow’"},{"parameters":{"curlImport":"","method":"GET","url":"http://host.docker.internal:8000/n8n-ping","authentication":"none","provideSslCertificates":false,"sendQuery":false,"sendHeaders":false,"sendBody":false,"options":{},"infoMessage":""},"type":"n8n-nodes-base.httpRequest","typeVersion":4.4,"position":[192,64],"id":"ae47912b-48d0-4628-80bb-e871690e57d9","name":"HTTP Request"}],"connections":{"When clicking ‘Execute workflow’":{"main":[[{"node":"HTTP Request","type":"main","index":0}]]}},"settings":{"executionOrder":"v1","binaryMode":"separate"},"staticData":null,"pinData":{}}	[{"version":1,"startData":"1","resultData":"2","executionData":"3","resumeToken":"4"},{"destinationNode":"5","runNodeFilter":"6"},{"runData":"7","pinData":"8","lastNodeExecuted":"9"},{"contextData":"10","nodeExecutionStack":"11","metadata":"12","waitingExecution":"13","waitingExecutionSource":"14","runtimeData":"15"},"a957c3dc937dcf2811d5017446012d2fbdc0367f3a369804c89707ba9e17f8e7",{"nodeName":"9","mode":"16"},["17","9"],{"When clicking ‘Execute workflow’":"18","HTTP Request":"19"},{},"HTTP Request",{"node:HTTP Request":"20"},[],{},{},{},{"version":1,"establishedAt":1778138581762,"source":"21","redaction":"22","triggerNode":"23"},"inclusive","When clicking ‘Execute workflow’",["24"],["25"],{"response":"26"},"manual",{"version":1,"policy":"27"},{"name":"9","type":"28"},{"startTime":1778137259871,"executionIndex":0,"source":"29","hints":"30","executionTime":1,"executionStatus":"31","data":"32"},{"startTime":1778138581769,"executionIndex":1,"source":"33","hints":"34","executionTime":18,"executionStatus":"31","data":"35"},{"body":"36"},"none","n8n-nodes-base.httpRequest",[],[],"success",{"main":"37"},["38"],[],{"main":"39"},{"reachable":true,"service":"40"},["41"],{"previousNode":"17","previousNodeOutput":0,"previousNodeRun":0},["42"],"devsignal-api",["43"],["44"],{"json":"45","pairedItem":"46"},{"json":"36","pairedItem":"47"},{},{"item":0},{"item":0}]	785c1aca-de59-46db-a102-7e5a9a6fb0cc
20	{"id":"AlrynH2aZBv1h5NT","name":"DevSignal — Main Pipeline","active":false,"activeVersionId":null,"isArchived":false,"createdAt":"2026-04-24T14:28:48.417Z","updatedAt":"2026-05-06T15:40:46.090Z","nodes":[{"parameters":{"notice":"","rule":{"interval":[{"field":"hours","hoursInterval":12,"triggerAtMinute":0}]}},"id":"b38e6f47-0ed0-45d9-a630-e43103d9b9a4","name":"Every 12 Hours","type":"n8n-nodes-base.scheduleTrigger","typeVersion":1.2,"position":[-480,128]},{"parameters":{"curlImport":"","method":"POST","url":"http://host.docker.internal:8000/run-pipeline","authentication":"none","provideSslCertificates":false,"sendQuery":false,"sendHeaders":true,"specifyHeaders":"keypair","headerParameters":{"parameters":[{"name":"X-Api-Key","value":"devsignal-local-key-2024"}]},"sendBody":false,"options":{"response":{"response":{"fullResponse":true,"neverError":false,"responseFormat":"autodetect"}},"timeout":4000000},"infoMessage":""},"id":"9616ca6d-5bb5-4253-a71f-8b0ce2579597","name":"Trigger Pipeline","type":"n8n-nodes-base.httpRequest","typeVersion":4.2,"position":[-240,128],"onError":"continueErrorOutput"},{"parameters":{"mode":"runOnceForAllItems","language":"javaScript","jsCode":"const response = $input.first().json;\\nconst body = response.body || response;\\nconsole.log('Pipeline status:', body.status);\\nconsole.log('Preview:', (body.preview || '').slice(-300));\\nreturn [{ json: { status: 'success', data: body } }];","notice":""},"id":"e8edd62b-4643-469c-9e33-08d99f49cbd6","name":"Log Success","type":"n8n-nodes-base.code","typeVersion":2,"position":[0,0]},{"parameters":{"mode":"runOnceForAllItems","language":"javaScript","jsCode":"const error = $input.first().json;\\nconst detail = error.error?.detail || error.message || 'Unknown error';\\nconst msg = typeof detail === 'object' ? JSON.stringify(detail) : String(detail);\\nconsole.error('Pipeline failed:', msg.slice(0, 500));\\nreturn [{ json: { status: 'failed', error_message: msg.slice(0, 1000) } }];","notice":""},"id":"c35065a3-6aa5-4045-be9b-09be07881794","name":"Parse Error","type":"n8n-nodes-base.code","typeVersion":2,"position":[0,240]},{"parameters":{"curlImport":"","method":"POST","url":"=https://api.telegram.org/bot{{ $env.TELEGRAM_BOT_TOKEN }}/sendMessage","authentication":"none","provideSslCertificates":false,"sendQuery":false,"sendHeaders":false,"sendBody":true,"contentType":"json","specifyBody":"keypair","bodyParameters":{"parameters":[{"name":"","value":""}]},"options":{},"infoMessage":""},"id":"8e6ca49a-ea77-4b21-921b-c447b52a6954","name":"Telegram Error Alert","type":"n8n-nodes-base.httpRequest","typeVersion":4.2,"position":[240,240]}],"connections":{"Every 12 Hours":{"main":[[{"node":"Trigger Pipeline","type":"main","index":0}]]},"Trigger Pipeline":{"main":[[{"node":"Log Success","type":"main","index":0}],[{"node":"Parse Error","type":"main","index":0}]]},"Parse Error":{"main":[[{"node":"Telegram Error Alert","type":"main","index":0}]]}},"settings":{"executionOrder":"v1","binaryMode":"separate"},"staticData":{"node:Every 12 Hours":{"recurrenceRules":[2]}},"pinData":{}}	[{"version":1,"startData":"1","resultData":"2","executionData":"3","resumeToken":"4"},{},{"runData":"5","pinData":"6","lastNodeExecuted":"7"},{"contextData":"8","nodeExecutionStack":"9","metadata":"10","waitingExecution":"11","waitingExecutionSource":"12","runtimeData":"13"},"5511f73bb3500282725e34f090da9b9a2f4ffa0b53881d74073d6fef2b97216f",{"Every 12 Hours":"14","Trigger Pipeline":"15","Log Success":"16"},{},"Log Success",{"node:Trigger Pipeline":"17"},[],{},{},{},{"version":1,"establishedAt":1778139517975,"source":"18","redaction":"19","triggerNode":"20"},["21"],["22"],["23"],{"response":"24"},"manual",{"version":1,"policy":"25"},{"name":"26","type":"27"},{"startTime":1778139517981,"executionIndex":0,"source":"28","hints":"29","executionTime":9,"executionStatus":"30","data":"31"},{"startTime":1778139517991,"executionIndex":1,"source":"32","hints":"33","executionTime":44,"executionStatus":"30","data":"34"},{"startTime":1778139518036,"executionIndex":2,"source":"35","hints":"36","executionTime":50,"executionStatus":"30","data":"37"},{"body":"38","headers":"39","statusCode":200,"statusMessage":"40"},"none","Every 12 Hours","n8n-nodes-base.scheduleTrigger",[],[],"success",{"main":"41"},["42"],[],{"main":"43"},["44"],[],{"main":"45"},{"status":"46","pid":77062,"message":"47"},{"date":"48","server":"49","content-length":"50","content-type":"51","connection":"52"},"OK",["53"],{"previousNode":"26","previousNodeOutput":0,"previousNodeRun":0},["54","55"],{"previousNode":"56","previousNodeOutput":0,"previousNodeRun":0},["57"],"started","Pipeline triggered successfully","Thu, 07 May 2026 07:38:37 GMT","uvicorn","76","application/json","close",["58"],["59"],[],"Trigger Pipeline",["60"],{"json":"61","pairedItem":"62"},{"json":"63","pairedItem":"64"},{"json":"65","pairedItem":"66"},{"timestamp":"67","Readable date":"68","Readable time":"69","Day of week":"70","Year":"71","Month":"72","Day of month":"73","Hour":"74","Minute":"75","Second":"76","Timezone":"77"},{"item":0},{"body":"38","headers":"39","statusCode":200,"statusMessage":"40"},{"item":0},{"status":"30","data":"78"},{"item":0},"2026-05-07T13:08:37.983+05:30","May 7th 2026, 1:08:37 pm","1:08:37 pm","Thursday","2026","May","07","13","08","37","Asia/Kolkata (UTC+05:30)",{"status":"46","pid":77062,"message":"47"}]	c2fe07de-5bfc-470d-94ed-072de0da5de1
21	{"id":"AlrynH2aZBv1h5NT","name":"DevSignal — Main Pipeline","active":false,"activeVersionId":null,"isArchived":false,"createdAt":"2026-04-24T14:28:48.417Z","updatedAt":"2026-05-06T15:40:46.090Z","nodes":[{"parameters":{"notice":"","rule":{"interval":[{"field":"hours","hoursInterval":12,"triggerAtMinute":0}]}},"id":"b38e6f47-0ed0-45d9-a630-e43103d9b9a4","name":"Every 12 Hours","type":"n8n-nodes-base.scheduleTrigger","typeVersion":1.2,"position":[-480,128]},{"parameters":{"curlImport":"","method":"POST","url":"http://host.docker.internal:8000/run-pipeline","authentication":"none","provideSslCertificates":false,"sendQuery":false,"sendHeaders":true,"specifyHeaders":"keypair","headerParameters":{"parameters":[{"name":"X-Api-Key","value":"devsignal-local-key-2024"}]},"sendBody":false,"options":{"response":{"response":{"fullResponse":true,"neverError":false,"responseFormat":"autodetect"}},"timeout":4000000},"infoMessage":""},"id":"9616ca6d-5bb5-4253-a71f-8b0ce2579597","name":"Trigger Pipeline","type":"n8n-nodes-base.httpRequest","typeVersion":4.2,"position":[-240,128],"onError":"continueErrorOutput"},{"parameters":{"mode":"runOnceForAllItems","language":"javaScript","jsCode":"const response = $input.first().json;\\nconst body = response.body || response;\\nconsole.log('Pipeline status:', body.status);\\nconsole.log('Preview:', (body.preview || '').slice(-300));\\nreturn [{ json: { status: 'success', data: body } }];","notice":""},"id":"e8edd62b-4643-469c-9e33-08d99f49cbd6","name":"Log Success","type":"n8n-nodes-base.code","typeVersion":2,"position":[0,0]},{"parameters":{"mode":"runOnceForAllItems","language":"javaScript","jsCode":"const error = $input.first().json;\\nconst detail = error.error?.detail || error.message || 'Unknown error';\\nconst msg = typeof detail === 'object' ? JSON.stringify(detail) : String(detail);\\nconsole.error('Pipeline failed:', msg.slice(0, 500));\\nreturn [{ json: { status: 'failed', error_message: msg.slice(0, 1000) } }];","notice":""},"id":"c35065a3-6aa5-4045-be9b-09be07881794","name":"Parse Error","type":"n8n-nodes-base.code","typeVersion":2,"position":[0,240]},{"parameters":{"curlImport":"","method":"POST","url":"=https://api.telegram.org/bot{{ $env.TELEGRAM_BOT_TOKEN }}/sendMessage","authentication":"none","provideSslCertificates":false,"sendQuery":false,"sendHeaders":false,"sendBody":true,"contentType":"json","specifyBody":"keypair","bodyParameters":{"parameters":[{"name":"","value":""}]},"options":{},"infoMessage":""},"id":"8e6ca49a-ea77-4b21-921b-c447b52a6954","name":"Telegram Error Alert","type":"n8n-nodes-base.httpRequest","typeVersion":4.2,"position":[240,240]}],"connections":{"Every 12 Hours":{"main":[[{"node":"Trigger Pipeline","type":"main","index":0}]]},"Trigger Pipeline":{"main":[[{"node":"Log Success","type":"main","index":0}],[{"node":"Parse Error","type":"main","index":0}]]},"Parse Error":{"main":[[{"node":"Telegram Error Alert","type":"main","index":0}]]}},"settings":{"executionOrder":"v1","binaryMode":"separate"},"staticData":{"node:Every 12 Hours":{"recurrenceRules":[2]}},"pinData":{}}	[{"version":1,"startData":"1","resultData":"2","executionData":"3","resumeToken":"4"},{},{"runData":"5","pinData":"6","lastNodeExecuted":"7"},{"contextData":"8","nodeExecutionStack":"9","metadata":"10","waitingExecution":"11","waitingExecutionSource":"12","runtimeData":"13"},"2d82de5a9e0fe78c8eaea48d2fa5a93b851310f1a5abca797605e0fcf7771d00",{"Every 12 Hours":"14","Trigger Pipeline":"15","Log Success":"16"},{},"Log Success",{"node:Trigger Pipeline":"17"},[],{},{},{},{"version":1,"establishedAt":1778147033145,"source":"18","redaction":"19","triggerNode":"20"},["21"],["22"],["23"],{"response":"24"},"manual",{"version":1,"policy":"25"},{"name":"26","type":"27"},{"startTime":1778147033151,"executionIndex":0,"source":"28","hints":"29","executionTime":1,"executionStatus":"30","data":"31"},{"startTime":1778147033153,"executionIndex":1,"source":"32","hints":"33","executionTime":33,"executionStatus":"30","data":"34"},{"startTime":1778147033186,"executionIndex":2,"source":"35","hints":"36","executionTime":10,"executionStatus":"30","data":"37"},{"body":"38","headers":"39","statusCode":200,"statusMessage":"40"},"none","Every 12 Hours","n8n-nodes-base.scheduleTrigger",[],[],"success",{"main":"41"},["42"],[],{"main":"43"},["44"],[],{"main":"45"},{"status":"46","pid":21266,"message":"47"},{"date":"48","server":"49","content-length":"50","content-type":"51","connection":"52"},"OK",["53"],{"previousNode":"26","previousNodeOutput":0,"previousNodeRun":0},["54","55"],{"previousNode":"56","previousNodeOutput":0,"previousNodeRun":0},["57"],"started","Pipeline triggered successfully","Thu, 07 May 2026 09:43:52 GMT","uvicorn","76","application/json","close",["58"],["59"],[],"Trigger Pipeline",["60"],{"json":"61","pairedItem":"62"},{"json":"63","pairedItem":"64"},{"json":"65","pairedItem":"66"},{"timestamp":"67","Readable date":"68","Readable time":"69","Day of week":"70","Year":"71","Month":"72","Day of month":"73","Hour":"74","Minute":"75","Second":"76","Timezone":"77"},{"item":0},{"body":"38","headers":"39","statusCode":200,"statusMessage":"40"},{"item":0},{"status":"30","data":"78"},{"item":0},"2026-05-07T15:13:53.152+05:30","May 7th 2026, 3:13:53 pm","3:13:53 pm","Thursday","2026","May","07","15","13","53","Asia/Kolkata (UTC+05:30)",{"status":"46","pid":21266,"message":"47"}]	c2fe07de-5bfc-470d-94ed-072de0da5de1
22	{"id":"AlrynH2aZBv1h5NT","name":"DevSignal — Main Pipeline","active":false,"activeVersionId":null,"isArchived":false,"createdAt":"2026-04-24T14:28:48.417Z","updatedAt":"2026-05-06T15:40:46.090Z","nodes":[{"parameters":{"notice":"","rule":{"interval":[{"field":"hours","hoursInterval":12,"triggerAtMinute":0}]}},"id":"b38e6f47-0ed0-45d9-a630-e43103d9b9a4","name":"Every 12 Hours","type":"n8n-nodes-base.scheduleTrigger","typeVersion":1.2,"position":[-480,128]},{"parameters":{"curlImport":"","method":"POST","url":"http://host.docker.internal:8000/run-pipeline","authentication":"none","provideSslCertificates":false,"sendQuery":false,"sendHeaders":true,"specifyHeaders":"keypair","headerParameters":{"parameters":[{"name":"X-Api-Key","value":"devsignal-local-key-2024"}]},"sendBody":false,"options":{"response":{"response":{"fullResponse":true,"neverError":false,"responseFormat":"autodetect"}},"timeout":4000000},"infoMessage":""},"id":"9616ca6d-5bb5-4253-a71f-8b0ce2579597","name":"Trigger Pipeline","type":"n8n-nodes-base.httpRequest","typeVersion":4.2,"position":[-240,128],"onError":"continueErrorOutput"},{"parameters":{"mode":"runOnceForAllItems","language":"javaScript","jsCode":"const response = $input.first().json;\\nconst body = response.body || response;\\nconsole.log('Pipeline status:', body.status);\\nconsole.log('Preview:', (body.preview || '').slice(-300));\\nreturn [{ json: { status: 'success', data: body } }];","notice":""},"id":"e8edd62b-4643-469c-9e33-08d99f49cbd6","name":"Log Success","type":"n8n-nodes-base.code","typeVersion":2,"position":[0,0]},{"parameters":{"mode":"runOnceForAllItems","language":"javaScript","jsCode":"const error = $input.first().json;\\nconst detail = error.error?.detail || error.message || 'Unknown error';\\nconst msg = typeof detail === 'object' ? JSON.stringify(detail) : String(detail);\\nconsole.error('Pipeline failed:', msg.slice(0, 500));\\nreturn [{ json: { status: 'failed', error_message: msg.slice(0, 1000) } }];","notice":""},"id":"c35065a3-6aa5-4045-be9b-09be07881794","name":"Parse Error","type":"n8n-nodes-base.code","typeVersion":2,"position":[0,240]},{"parameters":{"curlImport":"","method":"POST","url":"=https://api.telegram.org/bot{{ $env.TELEGRAM_BOT_TOKEN }}/sendMessage","authentication":"none","provideSslCertificates":false,"sendQuery":false,"sendHeaders":false,"sendBody":true,"contentType":"json","specifyBody":"keypair","bodyParameters":{"parameters":[{"name":"","value":""}]},"options":{},"infoMessage":""},"id":"8e6ca49a-ea77-4b21-921b-c447b52a6954","name":"Telegram Error Alert","type":"n8n-nodes-base.httpRequest","typeVersion":4.2,"position":[240,240]}],"connections":{"Every 12 Hours":{"main":[[{"node":"Trigger Pipeline","type":"main","index":0}]]},"Trigger Pipeline":{"main":[[{"node":"Log Success","type":"main","index":0}],[{"node":"Parse Error","type":"main","index":0}]]},"Parse Error":{"main":[[{"node":"Telegram Error Alert","type":"main","index":0}]]}},"settings":{"executionOrder":"v1","binaryMode":"separate"},"staticData":{"node:Every 12 Hours":{"recurrenceRules":[2]}},"pinData":{}}	[{"version":1,"startData":"1","resultData":"2","executionData":"3","resumeToken":"4"},{"destinationNode":"5","runNodeFilter":"6"},{"runData":"7","pinData":"8","lastNodeExecuted":"9"},{"contextData":"10","nodeExecutionStack":"11","metadata":"12","waitingExecution":"13","waitingExecutionSource":"14","runtimeData":"15"},"f9c5f40cda53c021dd800489b151517a384f0bfba58bff29ea13c2c87a4e16ed",{"nodeName":"9","mode":"16"},["17","9"],{"Every 12 Hours":"18","Trigger Pipeline":"19"},{},"Trigger Pipeline",{"node:Trigger Pipeline":"20"},[],{},{},{},{"version":1,"establishedAt":1778150971581,"source":"21","redaction":"22","triggerNode":"23"},"inclusive","Every 12 Hours",["24"],["25"],{"response":"26"},"manual",{"version":1,"policy":"27"},{"name":"9","type":"28"},{"startTime":1778147033151,"executionIndex":0,"source":"29","hints":"30","executionTime":1,"executionStatus":"31","data":"32"},{"startTime":1778150971593,"executionIndex":1,"source":"33","hints":"34","executionTime":34,"executionStatus":"31","data":"35"},{"body":"36","headers":"37","statusCode":200,"statusMessage":"38"},"none","n8n-nodes-base.httpRequest",[],[],"success",{"main":"39"},["40"],[],{"main":"41"},{"status":"42","pid":50155,"message":"43"},{"date":"44","server":"45","content-length":"46","content-type":"47","connection":"48"},"OK",["49"],{"previousNode":"17","previousNodeOutput":0,"previousNodeRun":0},["50","51"],"started","Pipeline triggered successfully","Thu, 07 May 2026 10:49:30 GMT","uvicorn","76","application/json","close",["52"],["53"],[],{"json":"54","pairedItem":"55"},{"json":"56","pairedItem":"57"},{"timestamp":"58","Readable date":"59","Readable time":"60","Day of week":"61","Year":"62","Month":"63","Day of month":"64","Hour":"65","Minute":"66","Second":"67","Timezone":"68"},{"item":0},{"body":"36","headers":"37","statusCode":200,"statusMessage":"38"},{"item":0},"2026-05-07T15:13:53.152+05:30","May 7th 2026, 3:13:53 pm","3:13:53 pm","Thursday","2026","May","07","15","13","53","Asia/Kolkata (UTC+05:30)"]	c2fe07de-5bfc-470d-94ed-072de0da5de1
\.


--
-- Data for Name: execution_entity; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.execution_entity (id, finished, mode, "retryOf", "retrySuccessId", "startedAt", "stoppedAt", "waitTill", status, "workflowId", "deletedAt", "createdAt", "storedAt") FROM stdin;
18	f	manual	\N	\N	2026-05-07 07:01:30.776+00	2026-05-07 07:01:30.811+00	\N	error	CD2GddIS6pD1N23E	\N	2026-05-07 07:01:30.774+00	db
19	t	manual	\N	\N	2026-05-07 07:23:01.751+00	2026-05-07 07:23:01.788+00	\N	success	CD2GddIS6pD1N23E	\N	2026-05-07 07:23:01.735+00	db
7	t	trigger	\N	\N	2026-04-30 20:49:42.44+00	2026-04-30 20:51:55.502+00	\N	success	AlrynH2aZBv1h5NT	\N	2026-04-30 20:49:42.43+00	db
8	t	manual	\N	\N	2026-05-03 16:51:28.053+00	2026-05-03 16:51:28.41+00	\N	success	AlrynH2aZBv1h5NT	\N	2026-05-03 16:51:28.033+00	db
9	t	manual	\N	\N	2026-05-03 16:51:34.95+00	2026-05-03 16:51:34.988+00	\N	success	AlrynH2aZBv1h5NT	\N	2026-05-03 16:51:34.948+00	db
20	t	manual	\N	\N	2026-05-07 07:38:37.967+00	2026-05-07 07:38:38.087+00	\N	success	AlrynH2aZBv1h5NT	\N	2026-05-07 07:38:37.961+00	db
10	f	manual	\N	\N	2026-05-05 07:12:18.447+00	2026-05-05 07:37:44.588+00	\N	error	AlrynH2aZBv1h5NT	\N	2026-05-05 07:12:18.432+00	db
11	t	manual	\N	\N	2026-05-05 10:38:17.872+00	2026-05-05 10:38:17.899+00	\N	success	AlrynH2aZBv1h5NT	\N	2026-05-05 10:38:17.865+00	db
12	t	manual	\N	\N	2026-05-05 10:38:23.741+00	2026-05-05 10:38:23.823+00	\N	success	AlrynH2aZBv1h5NT	\N	2026-05-05 10:38:23.737+00	db
13	t	manual	\N	\N	2026-05-05 10:39:06.082+00	2026-05-05 10:39:06.136+00	\N	success	AlrynH2aZBv1h5NT	\N	2026-05-05 10:39:06.076+00	db
21	t	manual	\N	\N	2026-05-07 09:43:53.124+00	2026-05-07 09:43:53.196+00	\N	success	AlrynH2aZBv1h5NT	\N	2026-05-07 09:43:53.117+00	db
14	t	manual	\N	\N	2026-05-05 10:39:25.375+00	2026-05-05 10:39:25.421+00	\N	success	AlrynH2aZBv1h5NT	\N	2026-05-05 10:39:25.372+00	db
15	t	manual	\N	\N	2026-05-05 11:04:27.174+00	2026-05-05 11:04:27.234+00	\N	success	AlrynH2aZBv1h5NT	\N	2026-05-05 11:04:27.164+00	db
16	t	manual	\N	\N	2026-05-06 15:41:01.708+00	2026-05-06 15:41:01.837+00	\N	success	AlrynH2aZBv1h5NT	\N	2026-05-06 15:41:01.705+00	db
17	f	manual	\N	\N	2026-05-07 07:00:59.783+00	2026-05-07 07:01:00.127+00	\N	error	CD2GddIS6pD1N23E	\N	2026-05-07 07:00:59.778+00	db
22	t	manual	\N	\N	2026-05-07 10:49:31.554+00	2026-05-07 10:49:31.627+00	\N	success	AlrynH2aZBv1h5NT	\N	2026-05-07 10:49:31.543+00	db
\.


--
-- Data for Name: execution_metadata; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.execution_metadata (id, "executionId", key, value) FROM stdin;
\.


--
-- Data for Name: folder; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.folder (id, name, "parentFolderId", "projectId", "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: folder_tag; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.folder_tag ("folderId", "tagId") FROM stdin;
\.


--
-- Data for Name: insights_by_period; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.insights_by_period (id, "metaId", type, value, "periodUnit", "periodStart") FROM stdin;
1	1	0	0	0	2026-04-28 20:00:00+00
2	1	2	1	0	2026-04-28 20:00:00+00
3	1	1	208902	0	2026-04-28 20:00:00+00
4	1	1	133035	0	2026-04-30 20:00:00+00
5	1	2	1	0	2026-04-30 20:00:00+00
6	1	0	0	0	2026-04-30 20:00:00+00
\.


--
-- Data for Name: insights_metadata; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.insights_metadata ("metaId", "workflowId", "projectId", "workflowName", "projectName") FROM stdin;
1	AlrynH2aZBv1h5NT	DGOtkH1dYuWz6cM8	DevSignal — Main Pipeline	Sahan Maiti <sahanmaiti2005@gmail.com>
\.


--
-- Data for Name: insights_raw; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.insights_raw (id, "metaId", type, value, "timestamp") FROM stdin;
\.


--
-- Data for Name: installed_nodes; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.installed_nodes (name, type, "latestVersion", package) FROM stdin;
\.


--
-- Data for Name: installed_packages; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.installed_packages ("packageName", "installedVersion", "authorName", "authorEmail", "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: instance_ai_iteration_logs; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.instance_ai_iteration_logs (id, "threadId", "taskKey", entry, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: instance_ai_messages; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.instance_ai_messages (id, "threadId", content, role, type, "resourceId", "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: instance_ai_observational_memory; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.instance_ai_observational_memory (id, "lookupKey", scope, "threadId", "resourceId", "activeObservations", "originType", config, "generationCount", "lastObservedAt", "pendingMessageTokens", "totalTokensObserved", "observationTokenCount", "isObserving", "isReflecting", "observedMessageIds", "observedTimezone", "bufferedObservations", "bufferedObservationTokens", "bufferedMessageIds", "bufferedReflection", "bufferedReflectionTokens", "bufferedReflectionInputTokens", "reflectedObservationLineCount", "bufferedObservationChunks", "isBufferingObservation", "isBufferingReflection", "lastBufferedAtTokens", "lastBufferedAtTime", metadata, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: instance_ai_resources; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.instance_ai_resources (id, "workingMemory", metadata, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: instance_ai_run_snapshots; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.instance_ai_run_snapshots ("threadId", "runId", "messageGroupId", "runIds", tree, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: instance_ai_threads; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.instance_ai_threads (id, "resourceId", title, metadata, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: instance_ai_workflow_snapshots; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.instance_ai_workflow_snapshots ("runId", "workflowName", "resourceId", status, snapshot, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: instance_version_history; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.instance_version_history (id, major, minor, patch, "createdAt") FROM stdin;
\.


--
-- Data for Name: invalid_auth_token; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.invalid_auth_token (token, "expiresAt") FROM stdin;
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjUzZDcxNzM2LWJhMWEtNDRhYi1iYTA4LThhOWZiZTVjZWUyNSIsImhhc2giOiJCaHFUdjU5WXVyIiwiYnJvd3NlcklkIjoiV0Z4Qm9BQzlYLy9GMmpaQ3pDNUhTNUx1ZHIzMUYrU2xjUVpuSCtzUzNldz0iLCJ1c2VkTWZhIjpmYWxzZSwiaWF0IjoxNzc3MDI2Njg1LCJleHAiOjE3Nzc2MzE0ODV9.amGZoqBBF7UxGz227Ushd9U16GiIQNO8SmuApAScmbA	2026-05-01 10:31:25+00
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjUzZDcxNzM2LWJhMWEtNDRhYi1iYTA4LThhOWZiZTVjZWUyNSIsImhhc2giOiJCaHFUdjU5WXVyIiwiYnJvd3NlcklkIjoiWHdScGdyeFJ4cC8vQ21uZVdPZXg3aHRubDJWQmdVVXQrOEtubTYxZ1BDYz0iLCJ1c2VkTWZhIjpmYWxzZSwiaWF0IjoxNzc3MDM4OTM4LCJleHAiOjE3Nzc2NDM3Mzh9.40W2bebAuADOI11Rm62l535T4H8Hq2eKSzjtK0Tkrbg	2026-05-01 13:55:38+00
\.


--
-- Data for Name: migrations; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.migrations (id, "timestamp", name) FROM stdin;
1	1587669153312	InitialMigration1587669153312
2	1589476000887	WebhookModel1589476000887
3	1594828256133	CreateIndexStoppedAt1594828256133
4	1607431743768	MakeStoppedAtNullable1607431743768
5	1611144599516	AddWebhookId1611144599516
6	1617270242566	CreateTagEntity1617270242566
7	1620824779533	UniqueWorkflowNames1620824779533
8	1626176912946	AddwaitTill1626176912946
9	1630419189837	UpdateWorkflowCredentials1630419189837
10	1644422880309	AddExecutionEntityIndexes1644422880309
11	1646834195327	IncreaseTypeVarcharLimit1646834195327
12	1646992772331	CreateUserManagement1646992772331
13	1648740597343	LowerCaseUserEmail1648740597343
14	1652254514002	CommunityNodes1652254514002
15	1652367743993	AddUserSettings1652367743993
16	1652905585850	AddAPIKeyColumn1652905585850
17	1654090467022	IntroducePinData1654090467022
18	1658932090381	AddNodeIds1658932090381
19	1659902242948	AddJsonKeyPinData1659902242948
20	1660062385367	CreateCredentialsUserRole1660062385367
21	1663755770893	CreateWorkflowsEditorRole1663755770893
22	1664196174001	WorkflowStatistics1664196174001
23	1665484192212	CreateCredentialUsageTable1665484192212
24	1665754637025	RemoveCredentialUsageTable1665754637025
25	1669739707126	AddWorkflowVersionIdColumn1669739707126
26	1669823906995	AddTriggerCountColumn1669823906995
27	1671535397530	MessageEventBusDestinations1671535397530
28	1671726148421	RemoveWorkflowDataLoadedFlag1671726148421
29	1673268682475	DeleteExecutionsWithWorkflows1673268682475
30	1674138566000	AddStatusToExecutions1674138566000
31	1674509946020	CreateLdapEntities1674509946020
32	1675940580449	PurgeInvalidWorkflowConnections1675940580449
33	1676996103000	MigrateExecutionStatus1676996103000
34	1677236854063	UpdateRunningExecutionStatus1677236854063
35	1677501636754	CreateVariables1677501636754
36	1679416281778	CreateExecutionMetadataTable1679416281778
37	1681134145996	AddUserActivatedProperty1681134145996
38	1681134145997	RemoveSkipOwnerSetup1681134145997
39	1690000000000	MigrateIntegerKeysToString1690000000000
40	1690000000020	SeparateExecutionData1690000000020
41	1690000000030	RemoveResetPasswordColumns1690000000030
42	1690000000030	AddMfaColumns1690000000030
43	1690787606731	AddMissingPrimaryKeyOnExecutionData1690787606731
44	1691088862123	CreateWorkflowNameIndex1691088862123
45	1692967111175	CreateWorkflowHistoryTable1692967111175
46	1693491613982	ExecutionSoftDelete1693491613982
47	1693554410387	DisallowOrphanExecutions1693554410387
48	1694091729095	MigrateToTimestampTz1694091729095
49	1695128658538	AddWorkflowMetadata1695128658538
50	1695829275184	ModifyWorkflowHistoryNodesAndConnections1695829275184
51	1700571993961	AddGlobalAdminRole1700571993961
52	1705429061930	DropRoleMapping1705429061930
53	1711018413374	RemoveFailedExecutionStatus1711018413374
54	1711390882123	MoveSshKeysToDatabase1711390882123
55	1712044305787	RemoveNodesAccess1712044305787
56	1714133768519	CreateProject1714133768519
57	1714133768521	MakeExecutionStatusNonNullable1714133768521
58	1717498465931	AddActivatedAtUserSetting1717498465931
59	1720101653148	AddConstraintToExecutionMetadata1720101653148
60	1721377157740	FixExecutionMetadataSequence1721377157740
61	1723627610222	CreateInvalidAuthTokenTable1723627610222
62	1723796243146	RefactorExecutionIndices1723796243146
63	1724753530828	CreateAnnotationTables1724753530828
64	1724951148974	AddApiKeysTable1724951148974
65	1726606152711	CreateProcessedDataTable1726606152711
66	1727427440136	SeparateExecutionCreationFromStart1727427440136
67	1728659839644	AddMissingPrimaryKeyOnAnnotationTagMapping1728659839644
68	1729607673464	UpdateProcessedDataValueColumnToText1729607673464
69	1729607673469	AddProjectIcons1729607673469
70	1730386903556	CreateTestDefinitionTable1730386903556
71	1731404028106	AddDescriptionToTestDefinition1731404028106
72	1731582748663	MigrateTestDefinitionKeyToString1731582748663
73	1732271325258	CreateTestMetricTable1732271325258
74	1732549866705	CreateTestRun1732549866705
75	1733133775640	AddMockedNodesColumnToTestDefinition1733133775640
76	1734479635324	AddManagedColumnToCredentialsTable1734479635324
77	1736172058779	AddStatsColumnsToTestRun1736172058779
78	1736947513045	CreateTestCaseExecutionTable1736947513045
79	1737715421462	AddErrorColumnsToTestRuns1737715421462
80	1738709609940	CreateFolderTable1738709609940
81	1739549398681	CreateAnalyticsTables1739549398681
82	1740445074052	UpdateParentFolderIdColumn1740445074052
83	1741167584277	RenameAnalyticsToInsights1741167584277
84	1742918400000	AddScopesColumnToApiKeys1742918400000
85	1745322634000	ClearEvaluation1745322634000
86	1745587087521	AddWorkflowStatisticsRootCount1745587087521
87	1745934666076	AddWorkflowArchivedColumn1745934666076
88	1745934666077	DropRoleTable1745934666077
89	1747824239000	AddProjectDescriptionColumn1747824239000
90	1750252139166	AddLastActiveAtColumnToUser1750252139166
91	1750252139166	AddScopeTables1750252139166
92	1750252139167	AddRolesTables1750252139167
93	1750252139168	LinkRoleToUserTable1750252139168
94	1750252139170	RemoveOldRoleColumn1750252139170
95	1752669793000	AddInputsOutputsToTestCaseExecution1752669793000
96	1753953244168	LinkRoleToProjectRelationTable1753953244168
97	1754475614601	CreateDataStoreTables1754475614601
98	1754475614602	ReplaceDataStoreTablesWithDataTables1754475614602
99	1756906557570	AddTimestampsToRoleAndRoleIndexes1756906557570
100	1758731786132	AddAudienceColumnToApiKeys1758731786132
101	1758794506893	AddProjectIdToVariableTable1758794506893
102	1759399811000	ChangeValueTypesForInsights1759399811000
103	1760019379982	CreateChatHubTables1760019379982
104	1760020000000	CreateChatHubAgentTable1760020000000
105	1760020838000	UniqueRoleNames1760020838000
106	1760116750277	CreateOAuthEntities1760116750277
107	1760314000000	CreateWorkflowDependencyTable1760314000000
108	1760965142113	DropUnusedChatHubColumns1760965142113
109	1761047826451	AddWorkflowVersionColumn1761047826451
110	1761655473000	ChangeDependencyInfoToJson1761655473000
111	1761773155024	AddAttachmentsToChatHubMessages1761773155024
112	1761830340990	AddToolsColumnToChatHubTables1761830340990
113	1762177736257	AddWorkflowDescriptionColumn1762177736257
114	1762763704614	BackfillMissingWorkflowHistoryRecords1762763704614
115	1762771264000	ChangeDefaultForIdInUserTable1762771264000
116	1762771954619	AddIsGlobalColumnToCredentialsTable1762771954619
117	1762847206508	AddWorkflowHistoryAutoSaveFields1762847206508
118	1763047800000	AddActiveVersionIdColumn1763047800000
119	1763048000000	ActivateExecuteWorkflowTriggerWorkflows1763048000000
120	1763572724000	ChangeOAuthStateColumnToUnboundedVarchar1763572724000
121	1763716655000	CreateBinaryDataTable1763716655000
122	1764167920585	CreateWorkflowPublishHistoryTable1764167920585
123	1764276827837	AddCreatorIdToProjectTable1764276827837
124	1764682447000	CreateDynamicCredentialResolverTable1764682447000
125	1764689388394	AddDynamicCredentialEntryTable1764689388394
126	1765448186933	BackfillMissingWorkflowHistoryRecords1765448186933
127	1765459448000	AddResolvableFieldsToCredentials1765459448000
128	1765788427674	AddIconToAgentTable1765788427674
129	1765804780000	ConvertAgentIdToUuid1765804780000
130	1765886667897	AddAgentIdForeignKeys1765886667897
131	1765892199653	AddWorkflowVersionIdToExecutionData1765892199653
132	1766064542000	AddWorkflowPublishScopeToProjectRoles1766064542000
133	1766068346315	AddChatMessageIndices1766068346315
134	1766500000000	ExpandInsightsWorkflowIdLength1766500000000
135	1767018516000	ChangeWorkflowStatisticsFKToNoAction1767018516000
136	1768402473068	ExpandModelColumnLength1768402473068
137	1768557000000	AddStoredAtToExecutionEntity1768557000000
138	1768901721000	AddDynamicCredentialUserEntryTable1768901721000
139	1769000000000	AddPublishedVersionIdToWorkflowDependency1769000000000
140	1769433700000	CreateSecretsProviderConnectionTables1769433700000
141	1769698710000	CreateWorkflowPublishedVersionTable1769698710000
142	1769784356000	ExpandSubjectIDColumnLength1769784356000
143	1769900001000	AddWorkflowUnpublishScopeToCustomRoles1769900001000
144	1770000000000	CreateChatHubToolsTable1770000000000
145	1770000000000	ExpandProviderIdColumnLength1770000000000
146	1770220686000	CreateWorkflowBuilderSessionTable1770220686000
147	1771417407753	AddScalingFieldsToTestRun1771417407753
148	1771500000000	MigrateExternalSecretsToEntityStorage1771500000000
149	1771500000001	AddUnshareScopeToCustomRoles1771500000001
150	1771500000002	AddFilesColumnToChatHubAgents1771500000002
151	1772000000000	AddSuggestedPromptsToAgentTable1772000000000
152	1772619247761	AddRoleColumnToProjectSecretsProviderAccess1772619247761
153	1772619247762	ChangeWorkflowPublishedVersionFKsToRestrict1772619247762
154	1772700000000	AddTypeToChatHubSessions1772700000000
155	1772800000000	CreateRoleMappingRuleTable1772800000000
156	1773000000000	CreateCredentialDependencyTable1773000000000
157	1774280963551	AddRestoreFieldsToWorkflowBuilderSession1774280963551
158	1774854660000	CreateInstanceVersionHistoryTable1774854660000
159	1775000000000	CreateInstanceAiTables1775000000000
160	1775116241000	CreateTokenExchangeJtiTable1775116241000
\.


--
-- Data for Name: oauth_access_tokens; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.oauth_access_tokens (token, "clientId", "userId") FROM stdin;
\.


--
-- Data for Name: oauth_authorization_codes; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.oauth_authorization_codes (code, "clientId", "userId", "redirectUri", "codeChallenge", "codeChallengeMethod", "expiresAt", state, used, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: oauth_clients; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.oauth_clients (id, name, "redirectUris", "grantTypes", "clientSecret", "clientSecretExpiresAt", "tokenEndpointAuthMethod", "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: oauth_refresh_tokens; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.oauth_refresh_tokens (token, "clientId", "userId", "expiresAt", "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: oauth_user_consents; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.oauth_user_consents (id, "userId", "clientId", "grantedAt") FROM stdin;
\.


--
-- Data for Name: opportunities; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.opportunities (id, date_found, job_source, apply_link, job_hash, company, role, location, remote, visa_sponsorship, experience_req, tech_stack, description_raw, recruiter_name, recruiter_role, linkedin_profile, email, opportunity_score, score_breakdown, outreach_message, applied, response_status, interview_stage, updated_at) FROM stdin;
137	2026-05-08 15:39:30.933408+00	Arc.dev	https://arc.dev/remote-jobs/j/we-are-meta-software-engineer-in-test-on9ht9zepb	41803987f600d6a952cf0a16d8f77b8f	We Are META	Software Engineer in Test	Remote	Yes	Unknown		ios, swift	We Are META Software Engineer in Test Full-time Swift Testing Software Development Project management Java JavaScript Kotlin Growth Appium XCUITest Api testing Remote - Portugal, Portugal 4 days ago					43	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 0}	This internship opportunity is a good fit due to its remote work option and iOS relevance, but lacks information on experience requirements and salary.	f			2026-05-08 16:50:59.008764+00
135	2026-05-08 15:39:30.933408+00	Google Jobs	https://jobs.ashbyhq.com/gen-digital/58523bde-7f09-45e3-9c25-1a6e49bfbe52	6e5bdf2cb32232b550056f2888d20fa5	Gen Digital Inc. - Jobs	Software Engineer Intern - LifeLock		Unknown	Unknown		swift	Monitor systems, identify potential issues, and ensure their swift resolution. Contribute to the creation and maintenance of documentation and procedures ...					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development and the required experience level, but lacks clear information on remote work, salary, and product quality.	f			2026-05-08 16:50:59.469918+00
136	2026-05-08 15:39:30.933408+00	Arc.dev	https://arc.dev/remote-jobs/j/bjak-ios-software-engineer-on9hhdekv2	f33784a64bac37bf4f156a9d8f6f4e81	BJAK	iOS Software Engineer	Remote	Yes	Unknown		ios, swift	BJAK iOS Software Engineer Full-time Swift iOS AI Software Development Ux writing SQL TensorFlow Concurrent Programming Support Responsive Design NoSQL Analysis SMM Remote - United Kingdom, United Kingdom 4 days ago					35	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 0, "experience_match": 0}	This internship opportunity is a good fit due to its remote work option and iOS relevance, but lacks information on experience requirements, product quality, salary, and visa sponsorship.	f			2026-05-08 16:50:59.802395+00
134	2026-05-07 10:32:25.607831+00	Google Jobs	https://job-boards.greenhouse.io/argmax/jobs/4067268009	aa34e986faf30a8cd659e18e5d25aac8	...	On-device AI Frameworks Engineer (Intern)		Unknown	Unknown		swift	3-6 months of hands-on experience in SDK or Frameworks development for iOS or Android · Familiarity with Swift OR (Kotlin AND C++) · Familiarity with profiling ...					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, remote work uncertainty, and entry-level experience requirements, but lacks clear information on salary, product quality, and visa sponsorship.	f			2026-05-08 16:51:00.190877+00
133	2026-05-07 07:39:40.230128+00	Adzuna	https://www.adzuna.co.uk/jobs/details/5721182825?utm_medium=api&utm_source=21a93cc1	bddff3fb6697776f2a44eb84d7f61511	Information Tech Consultants	Junior iOS Developer	Chalk Farm, North West London	Unknown	Unknown	1–2 years	swift, swiftui, uikit, xcode, ios sdk	Salary: £35,000 - 45,000 per year Requirements: 1–2 years of professional experience in iOS development (high-impact internships or freelance projects included) Strong foundational knowledge of Swift and the iOS SDK Basic understanding of C# (academic or project-based experience is acceptable) Familiarity with Auto Layout, UIKit, or SwiftUI A design-first mindset with an eye for detail and a passion for creating great user interfaces Experience with Git and Android Studio/Xcode Must be availabl…					43	{"visa": 0, "remote": 0, "salary": 10, "ios_relevance": 15, "product_quality": 8, "experience_match": 10}	This internship opportunity scores moderately due to its relevance to iOS development, but is limited by unclear remote work options, a mismatch in experience requirements, and a lack of clear product quality and visa sponsorship information.	f			2026-05-08 16:51:00.601157+00
129	2026-05-06 15:42:07.974055+00	Arc.dev	https://arc.dev/remote-jobs/j/housecall-pro-software-engineer-ii-developer-experience-brazil-obkipim6s0	0de7939ca9e753fe646656a794e9eb02	Housecall Pro	Software Engineer II (Developer Experience) - Brazil	Remote	Yes	Unknown		ios, swift	Housecall Pro Software Engineer II (Developer Experience) - Brazil Full-time iOS Ruby Ruby on Rails React Testing Software Development Android Version control Support Continuous Integration Operations JavaScript SQL Automation Git Amazon Cloud Innovation Team collaboration Communications Payment systems Data AI Growth CI/CD AWS Cloud Native Development Environment Debugging Data analytics Full Stack Code Review Remote - Brazil, Mexico, Philippines, Poland, Poland, United States New					43	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 0}	This internship opportunity is a good fit due to its remote work option and iOS relevance, but lacks clear experience requirements and salary information.	f			2026-05-08 16:51:01.077539+00
127	2026-05-06 15:42:07.974055+00	Google Jobs	https://jobs.ashbyhq.com/triumph-arcade/89d82fc2-c2dd-439d-bbc2-e3dcb298fffc	b91b30383762d4c909a3530eca3eb4de	Triumph - Jobs	Software Engineer Intern		Unknown	Unknown		swift	Mobile: Building features for our iOS apps in Swift or React Native. Working on real-time gameplay UI, push notifications, deep linking, and performance ...					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, remote work uncertainty, and entry-level requirements, but lacks clear information on salary, product quality, and visa sponsorship.	f			2026-05-08 16:51:21.81879+00
101	2026-04-28 21:22:14.753342+00	Arc.dev	https://arc.dev/remote-jobs/details/swift-swiftui-developer-ohpx55yqj1	904e5c68650cd356ec1e810cfb950c0f	FreelanceMid-levelHourly rateSwiftXcode	Swift/SwiftUI Developer	Remote	Yes	Unknown		ios, swift, swiftui, xcode	Arc Exclusive Fast apply Swift/SwiftUI Developer Freelance Mid-level Hourly rate Swift Xcode Remote - United States Actively hiring					35	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 0, "experience_match": 0}	This internship opportunity is a good fit due to its remote work option and iOS relevance, but lacks information on experience requirements, product quality, salary, and visa sponsorship.	f			2026-05-08 16:54:55.609005+00
130	2026-05-06 15:42:07.974055+00	Arc.dev	https://arc.dev/remote-jobs/j/remotehunter-software-engineer-platform-raleigh-nc-usa-on1pavt7bh	0f444df543c01788ff7e425d8131f0c4	RemoteHunter	Software Engineer, Platform - Raleigh, NC, USA	Remote	Yes	Unknown		ios, swift	RemoteHunter Software Engineer, Platform - Raleigh, NC, USA Full-time iOS Software Development Cloud Android TypeScript Node.js Amazon Payment systems Docker Back-End Kubernetes Google Cloud Platform Azure Support Ux writing macOS Web Development AI Data analytics Infrastructure AWS Remote - United States New					55	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 0, "experience_match": 20}	This internship opportunity is a good match due to its remote work option, entry-level experience requirements, and iOS relevance, but lacks clear information on product quality and salary.	f			2026-05-08 16:51:15.191269+00
131	2026-05-06 15:42:07.974055+00	Arc.dev	https://arc.dev/remote-jobs/j/quantum-health-lead-software-engineer-ui-mobile-development-on1rgl8eqn	040cdbf2adbc3f1d23641b9c2aa89974	Quantum Health	Lead Software Engineer - UI/Mobile Development	Remote	Yes	Unknown		ios, swift	Quantum Health Lead Software Engineer - UI/Mobile Development Full-time Lead iOS React React Native Java Software Development Spring Spring Boot TypeScript Database Amazon PostgreSQL Mobile App Development Responsive Design Security software Continuous Integration Product design JavaScript Data Back-End Android Web Development SQL Microsoft SQL Server DevOps Testing Project management Cloud Automation Support System security Ux writing UX design Design Systems Scalability Relational Database Test Automation Project documentation Communications AWS RESTful API Material-UI Ant Design CI/CD UI de					35	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 0, "experience_match": 0}	This internship opportunity is a good fit due to its remote work option and iOS relevance, but lacks information on experience requirements, salary, product quality, and visa sponsorship.	f			2026-05-08 16:51:30.289449+00
132	2026-05-06 15:42:07.974055+00	Arc.dev	https://arc.dev/remote-jobs/j/hims-hers-sr-software-engineer-app-on1pbtzv4f	cc19eaccb76ec53a8db85c6a7ab340aa	Shield AI	Sr. Software Engineer, App	Remote	Yes	Unknown		ios, swift	Shield AI Sr. Software Engineer, App Full-time Senior Swift Software Development Security software React React Native Design Architecture Kotlin System security Graphql.js Mobile App Development Scalability Testing Team collaboration Project management Architectural Design Product marketing Communications GraphQL Tools API User Testing Performance Optimization Monitoring Coding Style Design Patterns Problem solving Technical Support Mentoring Remote - United States New					35	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 0, "experience_match": 0}	This internship opportunity is a good fit due to its remote work option and iOS relevance, but lacks information on experience requirements, salary, product quality, and visa sponsorship.	f			2026-05-08 16:51:37.900038+00
125	2026-05-05 10:39:29.242597+00	Arc.dev	https://arc.dev/remote-jobs/j/scalepex-ux-designer-fully-remote-mexico-only-n00esdqvtt	f577462428b864572ddca622f2ff8383	Scalepex	UX Designer - Fully Remote - Mexico Only	Remote	Yes	Unknown		ios, swift	Scalepex UX Designer - Fully Remote - Mexico Only Full-time iOS Ux writing Product design Team collaboration Agile Android Software Development Research Growth Figma Linux Data Visualization UX design Web Development Design Systems Innovation Roadmap planning Design thinking Game Engine Development Jira Data Game Design Process improvement Support Visual design Interaction Design User flows Wireframing/prototyping Ideation Accessibility Remote - Mexico New					63	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good fit due to its remote work option, matching experience requirements, and use of Swift and iOS, but lacks clear information on salary and product funding.	f			2026-05-08 16:51:53.242533+00
126	2026-05-05 10:39:29.242597+00	Arc.dev	https://arc.dev/remote-jobs/j/pyramid-consulting-inc-software-engineer-la61tg2jdb	e88b5c84593cc30cf18df7963da5ca85	Pyramid Consulting, Inc	Software Engineer	Remote	Yes	Unknown		ios, swift, objective-c	Pyramid Consulting, Inc Software Engineer Freelance Swift React React Native iOS Android Mobile App Development Continuous Integration Testing Security software Software Development Kotlin Automation Compliance System security Scalability Research Data analytics Objective-C Java CI/CD Automated Tests Performance Optimization Security Optimizations Debugging Profiling Performance Testing Multi platform App Store Server Administration Remote - Mexico New					63	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its remote work option, entry-level experience requirements, and tech stack including Swift and iOS, but lacks clear information on salary and iOS product confirmation.	f			2026-05-08 16:52:08.33942+00
120	2026-05-03 16:52:32.734324+00	Arc.dev	https://arc.dev/remote-jobs/j/pavago-marketing-systems-engineer-ai-ad-tech-ombwdqs14h	1e53ed82c919a6f2fc43756c0a72bb14	Pavago	Marketing Systems Engineer (AI & Ad Tech)	Remote	Yes	Unknown		ios, swift	Pavago Marketing Systems Engineer (AI & Ad Tech) Full-time iOS Marketing strategies AI Automation React Python Data Software Development Next.js Performance marketing Embedded Systems Testing HubSpot Lead generation Campaign optimization Paid media Support Operations Data Pipelines Conversion tracking Go high level CRM Zapier API Webhooks Reporting Dashboards Remote - Pakistan New					55	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 0, "experience_match": 20}	This internship opportunity is a good fit due to its remote work option, matching experience requirements, and mention of iOS and Swift in the tech stack, but lacks clear information on product quality and salary.	f			2026-05-08 16:52:46.20247+00
113	2026-05-03 16:52:32.734324+00	WeWorkRemotely	https://weworkremotely.com/remote-jobs/stadium-product-owner	3c3af10ac24cf5396338ac7da8ccf659	Stadium	Product Owner	Remote	Yes	Unknown		combine	Headquarters: India We are looking for a Product Owner who is eager to learn, take ownership, and help shape how our teams build products that make a real difference. At Stadium , we’re building products that bring delight and connection to organizations worldwide. From thoughtful gifting to brand-building experiences, our platform combines creativity, data, and technology to make every interaction meaningful. In this role, you will work closely with a Senior Product Owner to translate business goals and user insights into clear, well-defined product features. You will collaborate with teams across Engineering, Design, Operations, Customer Success, and Marketing to design scalable, impactful solutions. This role is ideal for someone with experience in a startup or product-led environment w					63	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good fit due to its remote work option, entry-level experience requirements, and clear mention of iOS product development, but lacks specific salary information and clear iOS product confirmation.	f			2026-05-08 16:53:08.948498+00
109	2026-04-30 10:15:47.087131+00	Arc.dev	https://arc.dev/remote-jobs/j/jobgether-lead-product-designer-app-experience-oliyk2yuk1	8033599096c9169654410e321d9aa19e	Jobgether	Lead Product Designer - App Experience	Remote	Yes	Unknown		ios, swift	Jobgether Lead Product Designer - App Experience Full-time Lead iOS Android Data Product design Team collaboration Mobile UI Design thinking Mobile App Development Design Systems Layout Microinteractions User journey mapping Communications Experimentation GDPR AI Support Remote - United Kingdom, United Kingdom New					43	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 0}	This internship opportunity is a good fit due to its remote work option and iOS relevance, but lacks clear experience requirements and salary information.	f			2026-05-08 16:53:47.126075+00
105	2026-04-30 10:15:47.087131+00	WeWorkRemotely	https://weworkremotely.com/remote-jobs/flank-product-engineer	7af3252e5fa03823e1cee4b8c1d73cbe	Flank	Product Engineer	Remote	Yes	Unknown		swift	Headquarters: Berlin Flank is the leading Agentic AI platform for in-house legal teams—built for a future where autonomous AI colleagues handle entire workflows. Companies like TravelPerk, QA, and Mural use Flank to automate contract negotiation, email triage, and security reviews. What used to take hours of manual work now happens automatically. We're building in an emerging market that's reshaping how businesses operate. Instead of incremental software improvements, we're designing entirely new ways for AI and humans to collaborate. If you're excited about defining what's possible when AI becomes a true colleague, you'll find a home here. The Opportunity We’re looking for an AI-savvy, customer-centric Product Engineer to help us go boldly where no person has gone before! As a Product Eng					63	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good fit due to its remote work option, entry-level experience requirements, and use of Swift, but lacks clear information on iOS product confirmation and salary.	f			2026-05-08 16:54:02.289432+00
106	2026-04-30 10:15:47.087131+00	Google Jobs	https://jobs.ashbyhq.com/nord-security/164256dd-64c2-416e-97bb-96a376e6f1e8	9f5bd324ae26205e07d6b852356dc4c0		Agentic Product Engineer | Internship | Full-stack | Saily - Jobs		Unknown	Unknown		swift, swiftui, xcode, combine, spm	... SwiftUI, Xcode, Combine, SPM, MVVM Architecture - Android: Kotlin, Android ... Agentic Product Engineer | Internship | Full-stack | Saily. Location. Warsaw ...					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development and the fact that it's an internship, but lacks clear information on remote work, salary, and product quality.	f			2026-05-08 16:54:17.697514+00
104	2026-04-30 10:15:47.087131+00	WeWorkRemotely	https://weworkremotely.com/remote-jobs/updater-lead-devops-engineer	533ebe99f3072a1b82058d5167366018	Updater	Lead DevOps Engineer	Remote	Yes	Unknown		combine	Headquarters: Remote, US Join Updater’s Platform Engineering team as a Lead DevOps Engineer who combines technical excellence and exceptional collaboration skills to deliver impact. You will drive vital initiatives including deployment velocity, observability, system reliability, and developer experience. You'll build the infrastructure and tooling that lets engineers ship faster and sleep better—think GitOps workflows, Kubernetes configuration and optimization, comprehensive Datadog observability coverage, and the kind of automation that makes deployments uneventful. This is platform engineering done right: pragmatic, impactful, and centered on enabling the broader engineering organization. Key Responsibilities Embody a culture of continuous improvement and shared ownership backed by clea					28	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 0, "product_quality": 8, "experience_match": 0}	This internship opportunity is mostly attractive due to its remote work option, but lacks iOS relevance, clear experience requirements, and salary information.	f			2026-05-08 16:54:25.287192+00
103	2026-04-29 12:41:27.270298+00	Google Jobs	https://job-boards.greenhouse.io/eulerity/jobs/4671025006	e34d481ca9e82749d52fc26350654822	Eulerity	Mobile iOS Developer Intern		Unknown	Unknown			You'll own real work that ships to real users. Take an active role in developing, testing, and maintaining our iOS app using AI-first development practices — ...					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, remote work uncertainty, and entry-level experience requirements, but lacks clear information on salary, product quality, and visa sponsorship.	f			2026-05-08 16:54:40.393341+00
102	2026-04-28 21:22:14.753342+00	Arc.dev	https://arc.dev/remote-jobs/details/mobile-app-developer-ww-pt-ogi9xnc8at	7df8380f8b802984c40830a5bc8d3cbb	FreelanceSeniorHourly rateiOSApple healthkitReact	Mobile App Developer WW-PT	Remote	Yes	Unknown		ios, swift	Arc Exclusive Fast apply Mobile App Developer WW-PT Freelance Senior Hourly rate iOS Apple healthkit React Remote anywhere Actively hiring					35	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 0, "experience_match": 0}	This internship opportunity is a good fit due to its remote work option and iOS relevance, but lacks information on experience requirements, product quality, salary, and visa sponsorship.	f			2026-05-08 16:54:47.913197+00
96	2026-04-28 20:40:27.319801+00	Arc.dev	https://arc.dev/remote-jobs/j/presage-technologies-software-engineer-c-okt1zuuf24	d59368c487ed1b7cdd5f8aa777d6008b	Presage Technologies	Software Engineer (C++)	Remote	Yes	Unknown		ios, swift	Presage Technologies Software Engineer (C++) Full-time iOS Software Development C++ Testing React React Native Android QA Flutter Mobile App Development Data analytics AI Wireframing/prototyping Continuous Integration Version control Concurrent Programming Windows Application macOS Engineering Management Debugging Performance Optimization CI/CD Remote - United States 3 days ago					55	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 0, "experience_match": 20}	This internship opportunity is a good match due to its remote work option, entry-level experience requirements, and iOS relevance, but lacks clear information on product quality and salary.	f			2026-05-08 16:55:25.058109+00
99	2026-04-28 20:40:27.319801+00	Arc.dev	https://arc.dev/remote-jobs/j/crossing-hurdles-web-designer-65-hr-remote-okt6ydt1o4	7cf8f32c5031aa9c8a834edb7e8eab56	Crossing Hurdles	Web Designer | $65/hr Remote	Remote	Yes	Unknown		ios, swift, salary:$65/hr	Crossing Hurdles Web Designer | $65/hr Remote Freelance Swift Web Development React Vue.js Bootstrap Web Design SQL Java jQuery Amazon EC2 Scala Algorithm Cloud UX design Apache Spark E-commerce Research User Research Interface Design Data Apache Kafka System design Network Windows Application AI Communications Remote - Canada 3 days ago					65	{"visa": 0, "remote": 20, "salary": 10, "ios_relevance": 15, "product_quality": 0, "experience_match": 20}	This internship opportunity is a good match due to its remote work option, clear experience requirements, and specified compensation, but lacks clear iOS product confirmation and funding information.	f			2026-05-08 16:55:47.879693+00
107	2026-04-30 10:15:47.087131+00	Google Jobs	https://jobs.ashbyhq.com/ceezer/57e5697b-e72c-44f0-8668-775553468b7b?utm_source=q3gaJvlo1N	d0bb67ee1e1cc3990060e550d5b40d98	CEEZER - Jobs	Operations & Automations Intern (f/d/m)		Unknown	Unknown		swift	Swift adaptability to shifting priorities within a dynamic business environment. An analytical and data-driven mindset, along with proficient Excel skills.					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, remote work uncertainty, and entry-level experience requirements, but lacks clear information on salary, visa sponsorship, and iOS product confirmation.	f			2026-05-08 16:54:10.0929+00
97	2026-04-28 20:40:27.319801+00	Arc.dev	https://arc.dev/remote-jobs/j/outsourced-lead-product-designer-oh3a33vvmv	4c35e213e0347d56b7052f06a4e6bee5	Outsourced	Lead Product Designer	Remote	Yes	Unknown		ios, swift	Outsourced Lead Product Designer Full-time Lead iOS Team collaboration Ux writing Growth Product design Android Testing Research Web Development Mobile UI Support Design Systems User Research Usability testing Communications Storytelling UX design Mobile App Development UX/UI Design Accessibility Mentoring Visual design Interaction Design Advance prototyping Design Principles Remote - Philippines 3 days ago					43	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 0}	This internship opportunity is a good fit due to its remote work option and iOS relevance, but lacks clear experience requirements and salary information.	f			2026-05-08 16:56:17.131592+00
61	2026-04-26 16:43:44.294829+00	Arc.dev	https://arc.dev/remote-jobs/j/crossing-hurdles-full-stack-developer-65-hr-remote-okawzmeepb	be55bb614357a8d1a4173af8a98f2af1		Crossing Hurdles Full Stack Developer | $65/hr Remote Freelance Swift Web Development React Vue.js B	Remote	Yes	Unknown		salary:$65/hr, swift	Crossing Hurdles Full Stack Developer | $65/hr Remote Freelance Swift Web Development React Vue.js Bootstrap SQL Java jQuery Amazon EC2 Scala Algorithm Cloud Ux writing Apache Spark E-commerce Research User Research Interface Design Data Apache Kafka System design Network Windows Application AI Communications SkySpark Windows Server Remote Work Team collaboration Remote - Canada a day ago					65	{"visa": 0, "remote": 20, "salary": 10, "ios_relevance": 15, "product_quality": 0, "experience_match": 20}	This internship opportunity is a good fit due to its remote work option, matching experience requirements, and specified salary, but lacks clear iOS product confirmation and funding information.	f			2026-05-08 17:01:01.83347+00
94	2026-04-28 20:40:27.319801+00	Arc.dev	https://arc.dev/remote-jobs/j/the-judge-group-product-designer-native-mobile-experiences-okt6pc5jmr	502519fca8380f7fcdc8043fe89fbeab	The Judge Group	Product Designer - Native Mobile Experiences	Remote	Yes	Unknown		ios, swift	The Judge Group Product Designer - Native Mobile Experiences Freelance iOS Android Product design Web Development Mobile UI Design Systems Design Architecture Team collaboration Ux writing Support User flows Banking Scalability Material Design UX/UI Design Wireframing/prototyping Mentoring Financial Markets Accessibility for mobile Platform User Testing Leadership Remote - United States 3 days ago					35	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 0, "experience_match": 0}	This internship opportunity is a good fit due to its remote work option and iOS relevance, but lacks clear experience requirements and salary information.	f			2026-05-08 16:56:55.080816+00
91	2026-04-28 20:40:27.319801+00	Arc.dev	https://arc.dev/remote-jobs/details/swift-swiftui-developer-ohpx55yqj1	d94ba6dbcd4d0924a0122e71b376efc3	Arc ExclusiveFast apply	Swift/SwiftUI Developer	Remote	Yes	Unknown		ios, swift, swiftui, xcode	Arc Exclusive Fast apply Swift/SwiftUI Developer Freelance Mid-level Hourly rate Swift Xcode Remote - United States Actively hiring					35	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 0, "experience_match": 0}	This internship opportunity is a good fit due to its remote work option and iOS relevance, but lacks information on experience requirements, product quality, salary, and visa sponsorship.	f			2026-05-08 16:57:02.6226+00
78	2026-04-28 11:07:28.46273+00	Google Jobs	https://jobs.ashbyhq.com/gen-digital/3d190693-a4cc-47fb-bd60-268636d15a2e	b064bc3124849642d620d83b6b13feb7	Gen Digital Inc. - Jobs	Intern, Sales Operations		Unknown	Unknown		swift	... swift action impulses What you'll be working on · In this role, you'll help us build and improve how a global sales team actually works—using AI, data, and ...					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, remote work uncertainty, and entry-level experience requirements, but lacks clear information on salary, visa sponsorship, and iOS product confirmation.	f			2026-05-08 16:57:33.009682+00
79	2026-04-28 11:07:28.46273+00	Google Jobs	https://jobs.ashbyhq.com/kirin/38772f01-84fd-4f09-a36d-e7fa86341b99/application	22325cb1d824eb9808216454a403c270	Kirin - Jobs	Software Engineering Intern, AI Agents + Devices		Unknown	Unknown		swift	Software Engineering Intern, AI Agents + Devices. Location. Shenzhen; Hong ... Swift. Elixir. Node. AI Tools. Which harnesses do you use? Cursor. Windsurf.					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, remote work uncertainty, and entry-level experience requirements, but lacks clear information on salary, product quality, and visa sponsorship.	f			2026-05-08 16:58:17.601564+00
80	2026-04-28 11:07:28.46273+00	Arc.dev	https://arc.dev/remote-jobs/j/our-easy-game-tutoring-llc-ui-ux-designer-professional-in-educational-mobile-apps-okt6ms2w0v	b2f8ef015292f1b5ffbc90a70513a622		UI/UX Designer (Professional in Educational Mobile Apps)	Remote	Yes	Unknown		ios, swift	Our Easy Game Tutoring LLC UI/UX Designer (Professional in Educational Mobile Apps) Freelance iOS Ux writing Wireframing/prototyping Android Design Systems Testing Product design User flows Project management Research User Research UX design User journey mapping Payment systems Marketing strategies Data analytics Visual design UI design Mobile App Development Figma Advance prototyping Interactive Prototyping A/B testing Gameplay Social media engagement e-learning tools Remote - Lebanon 2 days ago					63	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its remote work option, entry-level experience requirements, and use of Swift and iOS, but lacks clear information on salary and product funding.	f			2026-05-08 16:58:26.099127+00
71	2026-04-27 06:24:59.943714+00	Arc.dev	https://arc.dev/remote-jobs/j/crossing-hurdles-full-stack-developer-65-hr-remote-okawzmeepb	5f40969ac8252c17ea50869dadf8f464		Full Stack Developer | $65/hr Remote	Remote	Yes	Unknown		ios, swift, salary:$65/hr	Crossing Hurdles Full Stack Developer | $65/hr Remote Freelance Swift Web Development React Vue.js Bootstrap SQL Java jQuery Amazon EC2 Scala Algorithm Cloud UX design Apache Spark E-commerce Research User Research Interface Design Data Apache Kafka System design Network Windows Application AI Communications Remote - United States 2 days ago					65	{"visa": 0, "remote": 20, "salary": 10, "ios_relevance": 15, "product_quality": 0, "experience_match": 20}	This internship opportunity is a good match due to its remote work option, clear experience requirements, and specified compensation, but lacks clear iOS product confirmation and funding information.	f			2026-05-08 16:59:04.059162+00
62	2026-04-27 06:24:59.943714+00	WeWorkRemotely	https://weworkremotely.com/remote-jobs/1nce-product-owner-frontend-all	d87d3b9c9182597f44b3ecc300691f39	1nce	Product Owner Frontend (all)	Remote	Yes	Unknown		combine	Headquarters: Remote A pioneering company at the forefront of transforming the IoT connectivity landscape. As a key player in the industry, we are on a mission to disrupt the telecommunications/ IoT landscape. With a focus on innovation, customer satisfaction, and industry leadership, 1NCE is set to change the game.We are looking for senior Product Owner to join our global project management team and take over Frontend project in telecommunication domain. This is a remote role with desired start date - &nbsp;June 2, 2025. "When you combine that with your own inspiration, plus the freedom and support to make your ideas happen, you can make a huge impact on how the IoT landscape evolves worldwide" - Gaurav Singh, VP Platform &amp; CMP. As a Product owner you will be responsible for the full 					63	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good fit due to its remote work option, entry-level experience requirements, and unclear but potentially suitable iOS product.	f			2026-05-08 16:59:34.684439+00
53	2026-04-26 16:43:44.294829+00	Arbeitnow	https://www.arbeitnow.com/jobs/companies/mirakl/enterprise-account-executive-dutch-speaker-munchen-361846	a5e7429ef58d181eadf12979aa2a4064	Mirakl	Enterprise Account Executive (Dutch Speaker)	München, Bavaria, Germany	Unknown	Unknown		combine	About Mirakl: &nbsp; Founded in 2012, Mirakl has been at the forefront of marketplace innovation, empowering every business to compete in the platform economy. Today, Mirakl's operating system combines an enterprise marketplace solution (Mirakl Platform) that enables retailers and B2B organizations to launch, scale, and operate marketplaces and dropship, AI-powered multichannel selling (Mirakl Connect), retail media (Mirakl Ads) and an agentic commerce infrastructure (Mirakl Nexus). With dual headquarters in Boston and Paris, Mirakl helps a global ecosystem of 450+ marketplaces (B2C and B2B) and a network of over 100k third-party marketplace sellers. Brands like Macy's, Decathlon, Carrefour, Asos, and Airbus Helicopters use Mirakl to grow their businesses in new and remarkable ways. &nbsp;					0	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 0, "product_quality": 0, "experience_match": 0}	No clear iOS relevance, on-site only, senior experience required, unclear product quality, no salary mentioned, and unknown visa sponsorship.	f			2026-05-08 16:59:58.222479+00
52	2026-04-24 13:43:53.197532+00	HackerNews	https://news.ycombinator.com/item?id=7829370	38f141b92774644e947a458b7b7c8d4e	Salt Lake City, UT -- Lucid Software (http://www.golucid.co)Lucid Software is building world class graphical applications in the browser and on mobile devices. Our first product, Lucidchart (http://ww	iOS Engineer	See post	Unknown	Unknown	2+ years	objective-c	Salt Lake City, UT -- Lucid Software ( http:&#x2F;&#x2F;www.golucid.co ) Lucid Software is building world class graphical applications in the browser and on mobile devices. Our first product, Lucidchart ( http:&#x2F;&#x2F;www.lucidchart.com ), is an online diagramming application with 1M+ users. We recently launched our second product, Lucidpress ( http:&#x2F;&#x2F;www.lucidpress.com ), which is an online layout and design application. Lucid is a startup founded by Karl Sun, a former Google exec, and Ben Dilts, our CTO. We&#x27;ve been profitable for 2+ years and recently closed our Series A. We are growing rapidly in every dimension of the business and need people to join our team. For fun we raft river rapids on company retreats, have Friday BBQs, and eat lots of pizza. Talent and abilit					0	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 0, "product_quality": 0, "experience_match": 0}	This internship opportunity is not suitable due to lack of iOS relevance, unclear remote work status, mismatched experience requirements, unclear product quality, no salary information, and unknown visa sponsorship.	f			2026-05-08 17:01:10.652041+00
39	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=10494537	d8fb065551f7117c8fc0b9228a89178c	Videotape • Austin, Texas (On-Site at Headquarters)	iOS Engineer	See post	Unknown	Unknown			Videotape • Austin, Texas (On-Site at Headquarters) Hiring Senior &amp; Junior iOS engineers Videotape is a first-of-its-kind interactive video app for iOS, launching this Fall. We currently have two in-house iOS engineers and continuing to grow our team. Are you motivated by being part of a determined, ambitious team solving complex problems and bringing beautifully engineered products to the market? Do you enjoy contributing to product decisions? Do you like working hard and meeting goals, but all the while goofing off with a really fun group of people? If yes, we want to talk to you. Looking at both senior and junior level candidates. Two years minimum iOS experience required. Experience with AV Foundation a plus, but not a requirement. Contact me, Stephen, at info@videotape.co to set u					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, remote work uncertainty, and entry-level experience requirements, but lacks clear salary and visa sponsorship information.	f			2026-05-08 17:01:35.354523+00
108	2026-04-30 10:15:47.087131+00	Google Jobs	https://jobs.ashbyhq.com/gen-digital/58523bde-7f09-45e3-9c25-1a6e49bfbe52	31b667da647a99ddd9e33e7d6e8dc59b	Gen Digital Inc. - Jobs	Software Engineer Intern - NortonLifeLock		Unknown	Unknown		swift	Monitor systems, identify potential issues, and ensure their swift resolution. Contribute to the creation and maintenance of documentation and procedures ...					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, remote work uncertainty, and entry-level experience requirements, but lacks clear information on salary, product quality, and visa sponsorship.	f			2026-05-08 16:53:54.707585+00
28	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=9812945	b472e2da1e27f2ae55c0b5a87a247a7c	Stryd, Boulder, CO, Techstars Boulder 2015	Full-time or Intern	iOS Developerhttp://www.stryd.comStryd is a multidisciplinary team that is enthusiastic about the future of wearable technology for athletes. Out of this passion, we've developed the world’s first wea	Unknown	Unknown		swift, objective-c	Stryd, Boulder, CO, Techstars Boulder 2015 | Full-time or Intern | iOS Developer http:&#x2F;&#x2F;www.stryd.com Stryd is a multidisciplinary team that is enthusiastic about the future of wearable technology for athletes. Out of this passion, we&#x27;ve developed the world’s first wearable power meter for runners that provides insight into their running technique and performance. For the iOS development, we use Swift primarily. But we want you to have deep understanding of Objective-C and the best practices of iOS programming. Good sense of design is bonus. We also want you to be an endurance runner, or a triathlete, or at least to have the passion about running. This is very important. Relocating to Boulder is required. But you know what? If you like running, this is pretty much your dream					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, remote work uncertainty, and entry-level experience requirements, but lacks clear information on salary, visa sponsorship, and iOS product confirmation.	f			2026-05-08 17:02:00.414251+00
4	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=9305238	9199d8e982105bcb48107e07c2e828d6	Hi-Art	Various Full-Time Engineering	New York City (USA)Hiring for CTO, Backend Engineer, and iOS EngineerHi-Art is a New York based app company (backed by a multi-billion dollar fund) that focuses on the intersection of art and messagin	Unknown	Unknown		swift, objective-c	Hi-Art | Various Full-Time Engineering | New York City (USA) Hiring for CTO, Backend Engineer, and iOS Engineer Hi-Art is a New York based app company (backed by a multi-billion dollar fund) that focuses on the intersection of art and messaging based communication. Our app features emoji &#x2F; stickers by prominent artists, musicians, films, and sports teams, culturally influential both in the US and internationally, including Cam’ron, Kid Ink, Verne Troyer, the Misfits, Ghostface Killah, Jason Derulo, and Todd James. Hi-Art has been featured in 50 publications including MTV, Pitchfork, Venturebeat, and Wired. In addition, we partner with global messaging apps. Broad Needs: - Should move comfortably between scripting languages (Python, Ruby, PHP, Go) - Solid understanding of and experienc					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, remote work uncertainty, and entry-level experience requirements, but lacks clear information on salary, visa sponsorship, and iOS product confirmation.	f			2026-05-08 17:02:42.203225+00
47	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=6655026	b3f9459fe75df14ece9089c1ca6f02f2	Refresh - Mountain View, CA - Fulltime - http://www.refresh.io	iOS Engineer	See post	Unknown	Unknown		objective-c	Refresh - Mountain View, CA - Fulltime - http:&#x2F;&#x2F;www.refresh.io email: jobs@refresh.io Must be local or willing to relocate (paid) A tagline of what we do is: Refresh helps connect people at a deeper level by providing realtime insights about them just as you&#x27;re about to meet them. The best description however is found by simply installing the app (Iphone only at the moment - we&#x27;re in the app store, Android soon - see job description below!) and trying it yourself. We&#x27;re super proud of the team we&#x27;ve built and we plan to keep the caliber high. We have exactly one requirement for hiring an engineer - it&#x27;s someone we&#x27;d like to work with. That&#x27;s a simple statement, but if you dig deeper, there&#x27;s a lot to it. It says that we think they&#x27;re s					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, but lacks clear information on remote work, salary, and visa sponsorship.	f			2026-05-08 17:02:50.711039+00
41	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=9307360	f953ecd659ac1f3f3cbf197dfde959af	MakeSpace	iOS Engineer	Full-time	Unknown	Unknown	1+ year	swift, core data	MakeSpace | iOS Engineer | Full-time | NYC MakeSpace is a next generation full-service storage company designed to take the pain out of using traditional self-storage units. With reservations available for scheduled drop-off and pick-up times, MakeSpace is taking the “self” out of self-storage, so customers never have to step foot in a storage facility again. MakeSpace lets users store bins of photo-catalogued items, viewable at any time on their MakeSpace account page, and all items are then easily retrievable: with the click of a button, selected boxes are delivered to customers in under 48 hours at their selected address. We are looking for a junior to mid level iOS Engineer to join our growing Mobile Engineering team, and help push new features to our suite of internal and consumer fac					23	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 0}	This internship opportunity has moderate iOS relevance, but lacks remote work flexibility, experience match, salary information, and visa sponsorship details.	f			2026-05-08 17:03:07.012849+00
43	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=33819024	36499006eba940d75db91eb2468a351e	Flexibits	Windows/Mac/iOS Software Engineers	Remote	Yes	Unknown		swift, swiftui, uikit, objective-c	Flexibits | Windows&#x2F;Mac&#x2F;iOS Software Engineers | Remote | Full-time https:&#x2F;&#x2F;flexibits.com&#x2F;jobs We make Fantastical and Cardhop, award-winning calendar and contacts apps for Mac and iOS. We are a 20 person, fully-remote company spread across the US and Europe, and welcome anyone from around the world. We prefer candidates that are in time zones between US Pacific Time and Central European Time. Tech stack: Objective-C, AppKit, UIKit, Swift, SwiftUI, C, C++, C#, WinUI. --- Software Engineer (Windows) We&#x27;re looking for an enthusiastic and experienced Windows developer to help bring the joy of Flexibits apps to Windows. This will include learning the ins and outs of Fantastical and Cardhop on macOS and iOS and bringing their magic to Windows, all the way from the 					63	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good fit due to its remote work option, experience match, and iOS relevance, but lacks clear information on salary and visa sponsorship.	f			2026-05-08 17:03:32.019286+00
1	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=31582845	8cc8e559d568be66d1355c0c1d7d7371	Roost	Remote international	Swift iOS + Desktop	Yes	Unknown		swift	Roost | Remote international | Swift iOS + Desktop | Contract-basis Hey there, I’m Josh and I’m working with my friend Jared on Roost. I’m a developer and Jared is a designer who codes. Roost is a private by design, offline-first, and ultimately open-source iOS and macOS app that makes it easy for people to get things done and manage life with the people they care about. Roosts are essentially chat rooms organized around topics with todo lists. Our vision is for Roost to have the security and privacy benefits of Signal via end-to-end encryption with the interface design and user experience of Things. We’ve already built a data and application layer in Go that provides an API for sending a message, creating a todo item, and all of the other functions needed to support the app. We also have 					63	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its remote work option, entry-level experience requirements, and focus on iOS development with Swift.	f			2026-05-08 17:03:56.642453+00
34	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=7973518	058b459669858b59543bbf3651c3df31	Bitmatica - San Francisco, CA - On-Site - Full Time - Junior iOS DeveloperWe're a small web and mobile development agency thats created dozens of successful applications for our clients. Given our exp	iOS Engineer	See post	Unknown	Unknown	1+ years of experience	objective-c	Bitmatica - San Francisco, CA - On-Site - Full Time - Junior iOS Developer We&#x27;re a small web and mobile development agency thats created dozens of successful applications for our clients. Given our explosive growth, we’re looking to hire a second freelance Junior iOS engineer. Your first project awaits you and will be full-time on-site in San Francisco’s Financial District. Why join our team? + You&#x27;ll learn and work alongside our experienced engineers + You&#x27;ll gain experience with dozens of technologies across multiple products + We have a designer on staff who provides beautiful, fully-spec&#x27;d UI&#x2F;UX + Our projects are all clearly spec&#x27;d + You&#x27;ll build multiple (not just one) applications for the most innovative companies in tech + Our culture is highly de					0	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 0, "product_quality": 0, "experience_match": 0}	This job opportunity is not suitable due to lack of iOS relevance, on-site requirement, and mismatched experience level.	f			2026-05-08 17:04:12.810852+00
35	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=4857844	6c7eba514485b065dceb1f51cb36f59a	AlpineReplay (Remote, anywhere)	iOS Engineer	See post	Yes	Unknown			AlpineReplay (Remote, anywhere) Junior iOS Engineer Company: We make action sports measurable, sharable, and comparable. If you like to play outside, you should come work with us. Email is in my profile					55	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 0, "experience_match": 20}	This internship opportunity is a good fit due to its remote work option, junior iOS engineer role, and lack of experience requirements, but lacks clear information about the iOS product and salary.	f			2026-05-08 17:04:29.282884+00
29	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=9641201	890a4678426cd74fe3f9029baaece6dc	Stryd, Boulder, CO	Intern	iOS Developerhttp://www.stryd.comStryd is a multidisciplinary team that is enthusiastic about the future of wearable technology for athletes. Out of this passion, we've developed the world’s first wea	Unknown	Unknown		swift, objective-c	Stryd, Boulder, CO | Intern | iOS Developer http:&#x2F;&#x2F;www.stryd.com Stryd is a multidisciplinary team that is enthusiastic about the future of wearable technology for athletes. Out of this passion, we&#x27;ve developed the world’s first wearable power meter for runners that provides insight into their running technique and performance. For the iOS development, we use Swift primarily. But we want you to have deep understanding of Objective-C and the best practices of iOS programming. Good sense of design is bonus. We also want you to be an endurance runner, or a triathlete, or at least to have the passion about running. Relocating to Boulder during the internship is required. But you know what? If you like running, this is pretty much your dream place. You get tons of opportunities t					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, remote work uncertainty, and entry-level experience requirements, but lacks clear information on salary and visa sponsorship.	f			2026-05-08 17:04:36.791688+00
66	2026-04-27 06:24:59.943714+00	Arc.dev	https://arc.dev/remote-jobs/j/dayforce-mobile-software-developer-lead-okaxm2eiou	91242e3bd27a608f410673b8a9d96b33		Mobile Software Developer Lead	Remote	Yes	Unknown		ios, swift	Dayforce Mobile Software Developer Lead Full-time Lead iOS Android Testing Kotlin Software Development Continuous Integration Data Java JSON Automation Security software Agile Communications Wireframing/prototyping Support Unit Testing Analysis Network QA Ux writing Flux Scalability System security Growth Roadmap planning Risk management AI Concurrent Programming Community management Web Development Gradle Jetpack Compose Coroutines Flow Dagger 2 Apache HTTP Client CI/CD Automated Tests UI Testing Dependency Manager Monitoring Security Optimizations Remote - North America, Antigua and Barbuda,					35	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 0, "experience_match": 0}	This internship opportunity is a good fit due to its remote work option and iOS relevance, but lacks information on experience requirements, product quality, salary, and visa sponsorship.	f			2026-05-08 16:59:49.719999+00
21	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=15151433	4c9e974e0b21f05f5c322ba1eb787574	Monzo	Backend, Data, iOS, Android & Web Engineers	London, UK	Yes	Unknown		swift	Monzo | Backend, Data, iOS, Android &amp; Web Engineers | London, UK | VISA, REMOTE, INTERNS https:&#x2F;&#x2F;monzo.com&#x2F; At Monzo we aim to build the best current account in the world. We are always keen to hear from capable, creative engineers who want to help us accomplish that goal. Our backend engineering team have a variety of different backgrounds: we have several non-graduates; only a couple of us studied Computer Science; one of the team has a degree in Marketing; some of us have worked in huge companies; some have only ever worked in startups; others are former consultants. As long as you enjoy learning new things, we’d love to talk to you. We work in project-based sprints, working directly with everyone across the company, from customer support to regulation, product to fin					63	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good fit due to its remote work option, experience match, and iOS relevance, but lacks clear information on salary and visa sponsorship.	f			2026-05-08 17:03:48.037123+00
45	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=7325105	080b9ad8b63b39e6460589c337423bb0	Savant Systems – Hyannis, MASavant is a home automation company, based heavily on the Apple platform. A Mac Mini or Linux host is used as the server to control your home, in tandem with our custom AV 	iOS Engineer	See post	Yes	Unknown		apple platform	Savant Systems – Hyannis, MA Savant is a home automation company, based heavily on the Apple platform. A Mac Mini or Linux host is used as the server to control your home, in tandem with our custom AV switches, lighting systems, and HVAC systems. Once setup, your home can be controlled from our iOS apps, our traditional remotes, or our new Android based universal remote. I&#x27;m a Software Engineer at Savant, and working there is definitely a great experience. You may fill one of these roles below, but you&#x27;ll get to work on a wide variety of projects, regardless your role. To give you a brief picture, day-to-day, I will work on firmware, Mac apps, iOS apps, Node.js web apps, and daemon processes that run on Mac and Linux. We&#x27;re looking to fill the following roles ASAP: - Senior 					43	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 0}	This internship opportunity is a good fit due to its remote work option and iOS relevance, but lacks clear experience requirements and salary information.	f			2026-05-08 17:04:45.388057+00
19	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=16972516	b0e7bc84f4c84c366b67cd23cbf84bfa	Nextdoor (http://nextdoor.com/)	San Francisco, CA	Full-time	Unknown	Unknown		swift, salary:$210	Nextdoor ( http:&#x2F;&#x2F;nextdoor.com&#x2F; ) | San Francisco, CA | Full-time | Onsite I&#x27;m one of the co-founders and Chief Architect at Nextdoor. Our mission is to use the power of technology to create stronger and safer neighborhoods all around the world. Over 85% of the neighborhoods in the US are using our platform to communicate about the issues most important to them, and we&#x27;ve just started expanding internationally as well in the Netherlands, UK, Germany, and France. Founded in 2010, we&#x27;re backed by Benchmark Capital, Greylock Partners, Google Ventures, and Tiger Global among others, and have raised over $210M in venture capital to-date. We are hiring across the board, and growing quickly. A list of our open job reqs can be found here at http:&#x2F;&#x2F;nextdoor.c					53	{"visa": 0, "remote": 0, "salary": 10, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, suitable experience requirements, and a clear salary, but lacks remote work confirmation and explicit iOS product confirmation.	f			2026-05-08 17:06:07.046398+00
3	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=11617652	4d2d3b9b3aeafab1006d95ff8fbd5f0f	Do you hire iOS interns who use Swift or is it mainly Objective-C?	iOS Engineer	See post	Unknown	Unknown		swift, objective-c	Do you hire iOS interns who use Swift or is it mainly Objective-C?					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, remote work status not being a concern, and the required experience matching the applicant's profile, but lacks information on salary and product quality.	f			2026-05-08 17:06:14.665502+00
20	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=15153548	bd7a599f1385d565d22071a1b0297dec	BaseUp	Android + iOS, Frontend or Full Stack Developers	Sydney, NSW, Australia	Unknown	Unknown		swift, combine	BaseUp | Android + iOS, Frontend or Full Stack Developers | Sydney, NSW, Australia | ONSITE, INTERNS | https:&#x2F;&#x2F;www.baseup.com.au BaseUp has created a parking management platform for CBD buildings, which combines a web portal, mobile apps and hardware to provide seamless management and access control. Our platform automates management tasks, generates cost recovery and provides employee benefits. The right candidate will be interested in: - Providing great user experiences. - Ensuring the security of our platform. - Effective applications of IoT to produce business value. - New ideas for offerings to our customers. We have recently closed a seed round, and are looking to hire 1-2 developers. A range of experience is welcome, and compensation will match. If you&#x27;re interested i					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, remote work uncertainty, and entry-level experience requirements, but lacks clear information on salary, visa sponsorship, and product quality.	f			2026-05-08 17:01:19.151681+00
48	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=30517246	da169ad7fed6498c3407153ad067f3b6	Enigma Labs	NYC, Onsite	VisaEnigma Labs[1] is the first well-resourced team of technologists to build a dedicated data, community and research platform for UAP/UFOs. Our founding group is made up of engineers, investigative 	Yes	Unknown		swift	Enigma Labs | NYC, Onsite | Visa Enigma Labs[1] is the first well-resourced team of technologists to build a dedicated data, community and research platform for UAP&#x2F;UFOs. Our founding group is made up of engineers, investigative journalists, data scientists, and physicists.[2] --- We&#x27;re massively ramping up hiring following a year of silent building. Our stack: - GQL &#x2F; Hasura, with Weaviate-powered search and analytics - iOS (Swift, Mapbox, Matrix client SDK, Apollo) - DS team analyzing in Python, BYOStack - k8s backend, powering distributed OCR and NLP - Matrix powered messaging (seeking engineer for Matrix client implementation) We have open roles on all of our teams: - iOS (Team Lead &amp; Junior) - ETL engineers - CV architect - Data visualization The Enigma Labs team is					43	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 0}	This internship opportunity is a good fit due to its remote work option and iOS relevance, but lacks clear experience requirements and salary information.	f			2026-05-08 17:07:46.135195+00
46	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=6833899	9d4e23810554c4c13d10776d301988bb	Refresh - Mountain View, CA - Fulltime - http://www.refresh.io email: jobs@refresh.ioMust be local or willing to relocate (paid)A tagline of what we do is: Refresh helps connect people at a deeper lev	iOS Engineer	See post	Unknown	Unknown		objective-c	Refresh - Mountain View, CA - Fulltime - http:&#x2F;&#x2F;www.refresh.io email: jobs@refresh.io Must be local or willing to relocate (paid) A tagline of what we do is: Refresh helps connect people at a deeper level by providing realtime insights about them just as you&#x27;re about to meet them. The best description however is found by simply installing the app (Iphone only at the moment - we&#x27;re in the app store, Android soon - see job description below!) and trying it yourself. We&#x27;re super proud of the team we&#x27;ve built and we plan to keep the caliber high. We have exactly one requirement for hiring an engineer - it&#x27;s someone we&#x27;d like to work with. That&#x27;s a simple statement, but if you dig deeper, there&#x27;s a lot to it. It says that we think they&#x27;re s					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, remote work uncertainty, and entry-level experience requirements, but lacks clear information on salary, visa sponsorship, and product quality.	f			2026-05-08 17:08:10.703735+00
112	2026-04-30 20:50:44.317483+00	Google Jobs	http://job-boards.greenhouse.io/argmax/jobs/4067268009	8cde616cd0c44ab8db0953b7a477cbab	Argmax	On-device AI Frameworks Engineer (Intern) - Greenhouse		Unknown	Unknown		swift	3-6 months of hands-on experience in SDK or Frameworks development for iOS or Android · Familiarity with Swift OR (Kotlin AND C++) · Familiarity with profiling ...					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, remote work uncertainty, and entry-level experience requirements, but lacks clear information on salary, product quality, and visa sponsorship.	f			2026-05-08 16:53:39.568258+00
138	2026-05-10 16:15:16.945196+00	Google Jobs	https://jobs.ashbyhq.com/triumph-arcade/89d82fc2-c2dd-439d-bbc2-e3dcb298fffc	18e3817793349221409e5a6c243c6aac	Triumph - Jobs	Software Engineer (Intern)		Unknown	Unknown		swift	Opportunities Include. Mobile: Building features for our iOS apps in Swift or React Native. Working on real-time gameplay UI, push notifications, deep ...					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, remote work uncertainty, and entry-level experience requirements, but lacks clear information on salary, product quality, and visa sponsorship.	f			2026-05-10 16:16:07.822879+00
141	2026-05-10 16:15:16.945196+00	Arc.dev	https://arc.dev/remote-jobs/j/smart-food-safe-quality-food-safety-management-software-ui-ux-designer-oo3c1l25un	4fa306b7dfd910d52bc1bb92773ab39d	Smart Food Safe : Quality & Food Safety Management Software	UI/UX Designer	Remote	Yes	Unknown		ios, swift	Smart Food Safe : Quality & Food Safety Management Software UI/UX Designer Full-time iOS Ux writing Software Development Wireframing/prototyping Compliance Operations Functional Programming Testing Agile HTML/CSS CSS3 Figma Android Web Development Responsive Design User flows Design Systems Mockups UX design Sketch Adobe XD Research User Research Usability testing Mobile UI Scalability Framer SOLID Principles ProtoPie Communications Team collaboration UI design Advance prototyping JavaScript Accessibility Lean UX Web Design Interaction Design Typography Remote - India a day ago					63	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its remote work option, entry-level experience requirements, and use of Swift and iOS, but lacks clear information on salary and product funding.	f			2026-05-10 16:16:08.983236+00
142	2026-05-10 16:15:16.945196+00	Arc.dev	https://arc.dev/remote-jobs/j/mantech-tak-elastic-search-software-engineer-oo32iuc9er	13f5f0d35fc7a04dce090bec445446f2	ManTech	TAK Elastic Search Software Engineer	Remote	Yes	Unknown		ios, swift	ManTech TAK Elastic Search Software Engineer Full-time iOS Software Development Android JavaScript HTML/CSS CSS3 Automation Elasticsearch Testing HTML5 Games SEO Wireframing/prototyping Java Python Ruby Security software Data Agile JSON Git Docker Continuous Integration Kubernetes Database SQL Windows Application Web Development GUI Ux writing System security NoSQL Compliance Data Management Remote - United States a day ago					55	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 0, "experience_match": 20}	This internship opportunity is a good match due to its remote work option, experience requirements, and iOS relevance, but lacks information on salary, product quality, and visa sponsorship.	f			2026-05-10 16:16:09.360554+00
144	2026-05-10 16:15:16.945196+00	Arc.dev	https://arc.dev/remote-jobs/j/lennox-lead-ui-ux-designer-oo3c7ka439	86b83b40b06c9f527141558336d247ca	Lennox	Lead - UI UX Designer	Remote	Yes	Unknown		ios, swift	Lennox Lead - UI UX Designer Full-time Lead Swift Ux writing Responsive Design UX design Marketing strategies Team collaboration Research Product design Community management Testing Hardware Web Development IoT Embedded Systems Software Development Data analytics Automation Figma Wireframing/prototyping HTML/CSS CSS3 React Roadmap planning UX analysis Content management Support Design thinking Digital product design Innovation Digital marketing Sketch Adobe XD Communications UX/UI Design B2B marketing B2C marketing Conversion Optimization Advance prototyping Mobile UI User Research A/B testing					43	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 0}	This internship opportunity is a good fit due to its remote work option and iOS relevance, but lacks clear experience requirements and salary information.	f			2026-05-10 16:16:16.466683+00
145	2026-05-10 16:15:16.945196+00	Arc.dev	https://arc.dev/remote-jobs/j/jobs-via-dice-founding-mobile-software-engineer-oo36lzmj8s	1383143ec98305348eb0a585cc2548a7	Jobs via Dice	Founding Mobile Software Engineer	Remote	Yes	Unknown		ios, swift	Jobs via Dice Founding Mobile Software Engineer Full-time Swift React React Native Software Development iOS Android TypeScript Ruby Ruby on Rails PostgreSQL Kotlin Mobile App Development Web Development Mobile UI User acquisition Next.js Expo Remote - United States 2 days ago					63	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good fit due to its remote work option, matching experience requirements, and iOS relevance, but lacks clear information on salary and product quality.	f			2026-05-10 16:16:24.010417+00
146	2026-05-10 16:15:16.945196+00	Arc.dev	https://arc.dev/remote-jobs/j/jobs-via-dice-mobile-software-engineer-100-remote-oo36vyptz8	2f8a3502ad579adc9f58bfd2b109cf38	Jobs via Dice	Mobile Software Engineer 100% Remote	Remote	Yes	Unknown		ios, swift	Jobs via Dice Mobile Software Engineer 100% Remote Full-time Swift Software Development iOS Android Web Development Kotlin Compliance Mobile App Development WCAG 2.0 Jetpack Compose Remote - United States 2 days ago					55	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 0, "experience_match": 20}	This internship opportunity is a good match due to its remote work option, experience requirements, and tech stack, but lacks clear information about the iOS product and salary.	f			2026-05-10 16:16:31.683127+00
148	2026-05-10 16:15:16.945196+00	Arc.dev	https://arc.dev/remote-jobs/j/abercrombie-fitch-co-sr-ux-designer-design-systems-a-f-co-oo3e65ih23	056cf37642dbef0b3acdc37623701248	Abercrombie & Fitch Co.	Sr. UX Designer, Design Systems - A&F Co.	Remote	Yes	Unknown		ios, swift	Abercrombie & Fitch Co. Sr. UX Designer, Design Systems - A&F Co. Full-time Senior Swift Figma Web Development HTML/CSS CSS3 JavaScript React Product design Kotlin Agile Project documentation Wireframing/prototyping Ux writing Community management Scalability Design Systems Responsive Design Digital product design Design thinking Team collaboration Communications Growth Research Support E-commerce WCAG AI Fonts Advance prototyping Server Theme Customization Multi platform Development Tokenization Remote - North America, Antigua and Barbuda, Bahamas, Barbade, Belize, Costa Rica, Cuba, Dominican					43	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 0}	This internship opportunity is a good fit due to its remote work option and iOS relevance, but lacks clear experience requirements and salary information.	f			2026-05-10 16:16:47.794733+00
63	2026-04-27 06:24:59.943714+00	Arc.dev	https://arc.dev/remote-jobs/details/swift-swiftui-developer-ohpx55yqj1	f6af0d767576aec66ae9683a3b80946e		Swift/SwiftUI Developer	Remote	Yes	Unknown		ios, swift, swiftui, xcode	Arc Exclusive Fast apply Swift/SwiftUI Developer Freelance Mid-level Hourly rate Swift Xcode Remote - United States Actively hiring					35	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 0, "experience_match": 0}	This internship opportunity is a good fit due to its remote work option and iOS relevance, but lacks information on experience requirements, product quality, salary, and visa sponsorship.	f			2026-05-08 16:58:40.429142+00
139	2026-05-10 16:15:16.945196+00	Google Jobs	https://jobs.ashbyhq.com/ceezer/c6f64315-30f5-4f59-978e-4e8a620d5d1f?utm_source=q3gaJvlo1N	e0d1018ca9f9e0e2a186deb3780523b5	CEEZER - Jobs	Founder's Associate Intern (f/d/m)		Unknown	Unknown		swift	Swift adaptability to shifting priorities within a dynamic business environment. An analytical and data-driven mindset, along with proficient Excel and ...					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, remote work uncertainty, and entry-level experience requirements.	f			2026-05-10 16:16:08.236086+00
140	2026-05-10 16:15:16.945196+00	Arc.dev	https://arc.dev/remote-jobs/j/u-s-soccer-federation-product-designer-mobile-oo3bzl5puf	d413ba14d5f9116d3b29e4bb8ee10bba	U.S. Soccer Federation	Product Designer, Mobile	Remote	Yes	Unknown		ios, swift	U.S. Soccer Federation Product Designer, Mobile Full-time iOS Android Game Engine Development Design Architecture Game Design Figma Wireframing/prototyping Mobile UI Product design Community management QA Support Mobile App Development Visual design Research User Research Data Growth Material Design Roadmap planning Scalability SOLID Principles Motion Graphics WCAG 2.0 Voice over Type systems Advance prototyping Remote - Gabon, United States a day ago					43	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 0}	This internship opportunity is a good fit due to its remote work option and iOS relevance, but lacks clear experience requirements and salary information.	f			2026-05-10 16:16:08.601123+00
143	2026-05-10 16:15:16.945196+00	Arc.dev	https://arc.dev/remote-jobs/j/hire-with-near-product-designer-oo3d5u89dv	45ef3a34b5f279e5df43605b473c3deb	Hire With Near	Product Designer	Remote	Yes	Unknown		ios, swift	Hire With Near Product Designer Full-time iOS Wireframing/prototyping Figma Ux writing Design Systems Mobile UI UX design Team collaboration AI Communications UI design Advance prototyping Interaction Design Mobile App Development Visual design Typography Spacy Component libraries User Testing Product design Video Editing Media Product marketing Remote Work Remote anywhere 2 days ago					43	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 0}	This internship opportunity is a good fit due to its remote work option and iOS relevance, but lacks clear experience requirements and salary information.	f			2026-05-10 16:16:10.894326+00
147	2026-05-10 16:15:16.945196+00	Arc.dev	https://arc.dev/remote-jobs/j/apetan-consulting-llc-lead-software-engineer-ios-remote-oo37idpyy7	5a9cccffce04563e168bf83a47a6cd4e	Apetan Consulting LLC	Lead Software Engineer – iOS/Remote	Remote	Yes	Unknown		ios, swift, uikit, objective-c, core data	Apetan Consulting LLC Lead Software Engineer – iOS/Remote Full-time Lead Swift iOS Software Development Testing Continuous Integration Git Mvc 5 Agile Scrum Version control Security software UIKit Data Core Data MvvmCross Communications Team collaboration Data analytics System security Objective-C RESTful API CI/CD Remote - United States 2 days ago					35	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 0, "experience_match": 0}	This internship opportunity is a good fit due to its remote work option and iOS relevance, but lacks information on experience requirements, salary, product quality, and visa sponsorship.	f			2026-05-10 16:16:39.250507+00
64	2026-04-27 06:24:59.943714+00	Arc.dev	https://arc.dev/remote-jobs/details/mobile-app-developer-ww-pt-ogi9xnc8at	26ff11b155bbb4d52f01be0b348565d2		Mobile App Developer WW-PT	Remote	Yes	Unknown		ios, swift	Arc Exclusive Fast apply Mobile App Developer WW-PT Freelance Senior Hourly rate iOS Apple healthkit React Remote anywhere Actively hiring					35	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 0, "experience_match": 0}	This internship opportunity is a good fit due to its remote work option and iOS relevance, but lacks information on experience requirements, product quality, salary, and visa sponsorship.	f			2026-05-08 16:59:42.173845+00
205	2026-05-11 06:22:40.960796+00	Google Jobs	https://job-boards.greenhouse.io/eulerity/jobs/4676832006	ca63d79270cae67e8abad7166569c9dd	Eulerity	Jobs at Eulerity - Greenhouse		Unknown	Unknown			Mobile iOS Developer. Pune, Maharashtra, India · Mobile iOS Developer Intern. New York, New York. Finance. Job. Director, Finance. New York, New York. Marketing ...					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity has a good match for the candidate's experience, but lacks clear information about remote work, salary, and iOS product confirmation.	f			2026-05-11 06:23:37.37891+00
215	2026-05-11 06:22:40.960796+00	Google Jobs	https://thehub.io/jobs/69f33cc638b05d4153e381ef	7fe72c15f74f1ad954c1e02189f80f45		iOS Developer Internship: The Global Native Transition (Swift/SwiftUI)		Unknown	Unknown		swift, swiftui	We are looking for an iOS Developer Intern (or postgrad working student) to be a foundational architect of this new codebase. We are building a native ...					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	A decent iOS internship opportunity with a clear tech stack, but unclear remote work and salary details, and a relatively small startup with an unknown iOS product.	f			2026-05-11 06:23:37.852195+00
216	2026-05-11 06:22:40.960796+00	Adzuna	https://www.adzuna.co.uk/jobs/details/5725553769?utm_medium=api&utm_source=21a93cc1	34afdd574dffc61372d5f455f5869c27	Information Tech Consultants	Junior iOS Developer	Chalk Farm, North West London	Unknown	Unknown	1–2 years	swift, swiftui, uikit, xcode, ios sdk	Salary: £35,000 - 45,000 per year Requirements: 1–2 years of professional experience in iOS development (high-impact internships or freelance projects included) Strong foundational knowledge of Swift and the iOS SDK Basic understanding of C# (academic or project-based experience is acceptable) Familiarity with Auto Layout, UIKit, or SwiftUI A design-first mindset with an eye for detail and a passion for creating great user interfaces Experience with Git and Android Studio/Xcode Must be availabl…					43	{"visa": 0, "remote": 0, "salary": 10, "ios_relevance": 15, "product_quality": 8, "experience_match": 10}	This internship opportunity scores moderately due to its relevance to iOS development, but is limited by unclear remote work options, a mismatch in experience requirements, and a lack of clear product quality and visa sponsorship information.	f			2026-05-11 06:23:38.379787+00
75	2026-04-28 11:07:28.46273+00	Google Jobs	https://jobs.lever.co/matchgroup/178e6f99-ddbb-43e1-9e4c-fe2b524e0861/apply?utm_source=Simplify&ref=Simplify	d7993ad5850138380b632519caa4a3c3	iOS Engineer Intern	Match Group		Hybrid	Unknown			iOS Engineer Intern. Los Angeles, California / Palo Alto, California. Tinder – Tindership & University Grads /. Internship /. Hybrid. Submit your application.					43	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 0}	This internship opportunity is a good fit due to its hybrid remote work option and iOS relevance, but lacks information on experience requirements and salary.	f			2026-05-08 16:57:55.780353+00
290	2026-05-12 06:01:53.843925+00	Google Jobs	https://jobs.ashbyhq.com/chainlink-labs/c71ed144-8eb4-4acf-9bf3-137b1b067ed8	1e02a2b834cafd72d59fcf32c70969e3	Chainlink Labs - Jobs	Research Internship		Unknown	Unknown		swift	Intern. Location ... Many of the world's largest financial services institutions have also adopted Chainlink's standards and infrastructure, including Swift ...					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	A decent opportunity with a good experience match, but unclear remote and salary information, and limited iOS product confirmation.	f			2026-05-12 06:02:44.885671+00
77	2026-04-28 11:07:28.46273+00	Google Jobs	https://jobs.ashbyhq.com/quora/56191d84-a55d-47ae-9cad-2842fc714ad1/?utm_source=ProductJobsAnywhere	6f50d38d6bc1166f3face941c9c11646	Quora	Software Engineer Intern - iOS, Poe (Canada - Remote)		Yes	Unknown			... iOS Engineer Intern on the Poe team, you'll help build one of the most exciting consumer AI products in the world. You'll work alongside experienced iOS ...					63	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its remote work option, clear experience requirements, and iOS relevance, but lacks salary information and explicit confirmation of iOS product.	f			2026-05-08 16:57:40.618377+00
8	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=36152287	f99c8b8f02d2eff47088dbb716921ce2	FAIRTIQ	REMOTE & flexible in CET +/-2h	80-100%	Yes	Unknown		swift	FAIRTIQ | REMOTE &amp; flexible in CET +&#x2F;-2h | 80-100% | FAIRTIQ ( https:&#x2F;&#x2F;fairtiq.com&#x2F;en&#x2F; ) is the leading software solution that disrupts public transport ticketing. We use innovative algorithms to detect user journeys using data collected by mobile sensors. Since the founding in 2016, our innovative, simple solution has been recognised internationally. Thanks to our strategic partnerships, we already cover the entire public transportation system in Switzerland – while also growing internationally, i.e. in Germany, Austria, France and other regions. Tech stack: * Architecture principles: Microservices, Continuous Integration &amp; Delivery, Domain Driven Design, MVVM, Hexagonal architecture, Zero downtime * Programming languages we use: iOS - Swift, Android - Kot					63	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good fit due to its remote work option, experience match, and tech stack, but lacks clear information on iOS product and salary.	f			2026-05-08 17:07:29.114972+00
89	2026-04-28 20:40:27.319801+00	Google Jobs	https://jobs.ashbyhq.com/eightsleep/b6c2e6f6-eadd-4d67-93e9-1426be4f2035	f7939120554fc80f788a2d3d9b12c51c	Eight Sleep - Jobs	AI/ML Research Internship		Unknown	Unknown		swift	... interns to work on AI/ML problems in the sleep fitness and personal health space ... Swift, Objective C or Java - Experience with ML libraries, such as ...					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	A decent opportunity with good experience match, but unclear remote status and no salary information.	f			2026-05-08 16:55:02.210149+00
26	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=12846500	8fdbf9fa7e553db2d2714a3c401fdf8f	Telemetricor LimitedA small end-to-end hardware/software company building real-time sensors and data interfaces. Our current focus is on TelemetriCop (radio mesh-networked cameras for rural security) 	Winchester, Hampshire, UK	Full-Time	Unknown	Unknown		swift	Telemetricor Limited A small end-to-end hardware&#x2F;software company building real-time sensors and data interfaces. Our current focus is on TelemetriCop (radio mesh-networked cameras for rural security) and TelemetriTrace (a retail loss prevention system). Our stack is primarily embedded C, PostgreSQL, and NodeJS, however there are a smattering of other languages where applicable. We are looking to hire for two new positions (our fourth and fifth employees): Machine Learning &#x2F; Data Scientist | Winchester, Hampshire, UK | Full-Time | ONSITE We are looking for someone to take on the task of improving the image classification in the TelemetriCop system (radio networked cameras), as well as help us build and improve the data analytics of the TelemetriTrace system. There is a lot of roo					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, remote work uncertainty, and entry-level experience requirements, but lacks clear information on salary, visa sponsorship, and iOS product confirmation.	f			2026-05-08 17:07:20.465093+00
100	2026-04-28 20:40:27.319801+00	Arc.dev	https://arc.dev/remote-jobs/j/crossing-hurdles-full-stack-developer-65-hr-remote-okawzmeepb	fc470f62ae83e2cf7b22ecfe025d3fad	Crossing Hurdles	Full Stack Developer | $65/hr Remote	Remote	Yes	Unknown		ios, swift, salary:$65/hr	Crossing Hurdles Full Stack Developer | $65/hr Remote Freelance Swift Web Development React Vue.js Bootstrap SQL Java jQuery Amazon EC2 Scala Algorithm Cloud UX design Apache Spark E-commerce Research User Research Interface Design Data Apache Kafka System design Network Windows Application AI Communications Remote - United States 4 days ago	Jeff Lam	Recruiting Director	https://www.linkedin.com/in/jefflam6	jeff@arc.dev	65	{"visa": 0, "remote": 20, "salary": 10, "ios_relevance": 15, "product_quality": 0, "experience_match": 20}	This internship opportunity is a good match due to its remote work option, clear experience requirements, and specified compensation, but lacks clear information about the iOS product and visa sponsorship.	f			2026-05-08 16:55:09.943522+00
84	2026-04-28 20:40:27.319801+00	Google Jobs	https://jobs.ashbyhq.com/sieve/b319e35e-2455-4c63-ae3d-721bc7dbffc9	c68c2768d29b0466664e51f0e0fc2f89	Sieve - Jobs	Software Engineering Intern		Unknown	Unknown		swift	... Swift Ventures, Y Combinator, and AI Grant. About the Role. As a software engineering intern at Sieve, you'll work across the stack to build and scale the ...					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, remote work uncertainty, and entry-level experience requirements, but lacks clear information on salary, visa sponsorship, and iOS product confirmation.	f			2026-05-08 16:55:17.545834+00
72	2026-04-28 11:07:28.46273+00	HackerNews	https://news.ycombinator.com/item?id=13110740	f7e2bda90225b5bb27f8ada5bee73e16	Big Nerd Ranch	Junior iOS Developer	Atlanta,GA	Unknown	Unknown	entry level	swift, xcode, objective-c	Big Nerd Ranch | Junior iOS Developer | Atlanta,GA | Onsite Big Nerd Ranch specializes in developing business-building mobile and web apps for our clients. We also teach students what we&#x27;ve learned through our signature immersive bootcamps, and every year we release new books in our best-selling series of Big Nerd Ranch Guides. We are looking for an entry level full-time iOS engineer to join the team. No professional experience required, but must be willing to learn and work hard. Exposure to architecture, design, configuration, the Xcode environment, Objective-C and Swift a plus. Learn more here https:&#x2F;&#x2F;www.bignerdranch.com&#x2F;about-us&#x2F;careers&#x2F;					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, entry-level experience requirements, and the company's focus on iOS app development, but lacks remote work and salary information.	f			2026-05-08 16:57:17.785131+00
15	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=25789997	2b231cabadc23042801c1f54becc51c5	Pessoal, vamos conversar sobre uma oportunidade internacional e remota? 🇺🇸Estou procurando um Lead iOS Engineer para trabalhar remotamente com um time dos Estados Unidos!Se você é brasileiro e tem o s	iOS Engineer	See post	Unknown	Unknown		swift	Pessoal, vamos conversar sobre uma oportunidade internacional e remota? 🇺🇸 Estou procurando um Lead iOS Engineer para trabalhar remotamente com um time dos Estados Unidos! Se você é brasileiro e tem o sonho de participar da criação de um produto do zero, liderando as tomadas de decisão na área técnica e ajudando a construir uma equipe focada em qualidade e escalabilidade, através da Ubiminds você pode fazer parte de uma empresa americana, que está começando agora e terá muitos desafios e oportunidades pela frente! Para isso você precisa... - Ser especialista em iOS, principalmente usando Swift - Ter um nível avançado&#x2F;fluente na conversação em inglês Fez sentido? Saiba mais e se candidate aqui! https:&#x2F;&#x2F;ubiminds.com&#x2F;job&#x2F;lead-ios-engineer-swift-with-ubimin... Ainda nã					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	Good match for a fresh graduate with iOS experience, but unclear about remote work and product details.	f			2026-05-08 17:06:47.79578+00
14	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=27705716	6305a5199d4b2ef738ac67efce4809d1	Storyboard	TryStoryboard.com	Los Angeles or RemoteSummary: Storyboard is a platform for companies & teams to collaborate through private, internal podcasts for their employees. We are a Seed stage company focused on creating tool	Yes	Unknown		swift	Storyboard | TryStoryboard.com | Los Angeles or Remote Summary: Storyboard is a platform for companies &amp; teams to collaborate through private, internal podcasts for their employees. We are a Seed stage company focused on creating tools for teams to communicate without live meetings. Over 2,000 companies globally have launched channels on Storyboard so far. To Apply: Please send resume to admin@trystoryboard.com Role: iOS Developer We&#x27;re looking for an iOS developer to help drive our native iOS app (Swift). As a podcast app, past background with audio&#x2F;music will be useful, as well as server-side experience (as a collaborator who will help us think through our architecture). If you&#x27;re interested in areas like audio or podcasting, we hope to chat.		Creative Talent Acquisition Manager.		admin@trystoryboard.com	63	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	A remote internship opportunity with Storyboard, a Seed stage company, that requires an iOS developer with no experience, but lacks clear salary and visa sponsorship information.	f			2026-05-08 17:06:55.644928+00
44	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=33422456	58d9fe99aa5fe836d6a32dee5ac24011	Flexibits	Mac/iOS/Windows Software Engineers	Remote	Yes	Unknown		swift, swiftui, uikit, objective-c	Flexibits | Mac&#x2F;iOS&#x2F;Windows Software Engineers | Remote | Full-time https:&#x2F;&#x2F;flexibits.com&#x2F;jobs We make Fantastical and Cardhop, award-winning calendar and contacts apps for Mac and iOS. We are a 20 person, fully-remote company spread across the US and Europe, and welcome anyone from around the world. We prefer candidates that are in time zones between US Pacific Time and Central European Time. Tech stack: Objective-C, AppKit, UIKit, Swift, SwiftUI, C, C++, C#, WinUI. --- Software Engineer (Mac &amp; iOS) We’re a small company, so you’ll be on the front lines creating apps that real people use every day. You&#x27;ll be adding new features to Fantastical and Cardhop, as well as hunting for bugs and helping to keep everything running smoothly for our users. Areas you&					43	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 0}	This internship opportunity is a good fit due to its remote work option and iOS relevance, but lacks clear experience requirements and salary information.	f			2026-05-08 17:07:04.099049+00
6	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=8828717	1302591d5676dcf9e1d492741be13e29	OMsignal Full Stack Software Engineer [REMOTE or LOCAL]Headquarters: Montreal	http://www.omsignal.comLink to Job Offer: https://github.com/OMsignal/omsignal-job-offers/blob/master/...OMsignal is made possible by the expertise of Smart Textile experts,	See post	Yes	Unknown		swift, ios sdk, cocoapods	OMsignal Full Stack Software Engineer [REMOTE or LOCAL] Headquarters: Montreal | http:&#x2F;&#x2F;www.omsignal.com Link to Job Offer: https:&#x2F;&#x2F;github.com&#x2F;OMsignal&#x2F;omsignal-job-offers&#x2F;blob&#x2F;master&#x2F;... OMsignal is made possible by the expertise of Smart Textile experts, Data&#x2F;Bio Scientists, Hardware, Firmware and Software Engineers. Please note that this offer is mostly focused on Full Stack Engineers, but we are also looking to hire smart Data Scientists who have an interest in biodata and possibly people who could help bridging BLE&#x2F;MSP firmware and driver development. What we do ========== OMsignal is an exciting Montreal start-up developing a revolutionary line of bio-sensing clothes that connect seamlessly to smartphones. The company is at the i					63	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its remote work option, entry-level experience requirements, and focus on iOS development, but lacks clear information on salary and visa sponsorship.	f			2026-05-08 17:07:12.86147+00
10	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=33425090	01bc8053ac00fee581c5fbb7db12b151	Psiphon	Software Engineer	https://psiphon.ca	Yes	Unknown		swift	Psiphon | Software Engineer | https:&#x2F;&#x2F;psiphon.ca | Toronto, Canada | Full-time | REMOTE for now, REMOTE&#x2F;ONSITE hybrid later Psiphon Inc. is looking for experienced software developers to join our Toronto team. = What we do = We develop and operate Psiphon, an Internet anti-censorship network that helps millions of people in freedom-restricted countries access uncensored Internet every day. We work at the leading edge of circumvention technology, where the latest network protocol and endpoint obfuscation research is rapidly deployed into production around the world. Our tasks include censorship technology research, server and client software development, and operation of a dynamic, global network of thousands of proxy servers. We’re a small team looking for skilled and enthus					63	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good fit due to its remote work option, experience match, and tech stack, but lacks clear iOS product confirmation and salary information.	f			2026-05-08 17:06:39.301094+00
111	2026-04-30 20:50:44.317483+00	WeWorkRemotely	https://weworkremotely.com/remote-jobs/meter-software-engineer-product	84532cb0cc6015e68ddad066fb750f4b	Meter	Software Engineer, Product	Remote	Yes	Unknown		swift	Headquarters: New York Our dashboard is the preeminent way our customers and partners interact with our products. It’s where complex networks become simple, where infrastructure decisions become clear, and where businesses gain confidence in their connectivity. As a product engineer at Meter, you’ll shape how companies visualize and interact with the networks that keep them running, transforming dense technical systems into intuitive, elegant, and performant experiences. The impact you’ll drive Create data visualizations that go beyond charts. You’ll give businesses real-time insight into device health, connectivity and performance. Ensure every interaction feels instantaneous by improving render, load, and scroll performance Adapt our dashboard to shine on any screen Build reusable visual					63	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good fit due to its remote work option, entry-level experience requirements, and focus on iOS development with Swift.	f			2026-05-08 16:53:32.913433+00
25	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=12850005	a8b1548bd80a5406aa57965c705c451e	John Hancock Digital	iOS Developer (Swift) & Full Stack Developer (Ruby) & QA Engineer	San Francisco, CA	Unknown	Unknown		swift	John Hancock Digital | iOS Developer (Swift) &amp; Full Stack Developer (Ruby) &amp; QA Engineer | San Francisco, CA | FULL TIME | ONSITE John Hancock Digital uses machine learning, mobile chat innovation and automated money management to help millions of families better manage their finances. Our team has the impact and excitement of a startup with the resources and stability of a Fortune 500 company. We are in the late stages of developing and launching a stealth prototype iOS product, using Swift and Ruby&#x2F;Rails. Our work also involves complex integrations with leading aggregation and clearing providers to enable real-time money movement, portfolio management and intelligent financial guidance. Our product will be released to an internal set of stakeholders in the coming weeks, whic					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, remote work uncertainty, and entry-level experience requirements, but lacks clear information on salary, visa sponsorship, and product quality.	f			2026-05-08 17:05:42.292014+00
18	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=18590017	3f2ad6c3c20baa1bfe5653c63a4d48ac	Genetec	Software Developers	Montreal (CA) or Paris (FR)	Yes	Unknown		swift	Genetec | Software Developers | Montreal (CA) or Paris (FR) | ONSITE Genetec - Global market leader of video surveillance solutions around the world is still expanding at an impressive rate. We offer a wide range of services for cities, airports, retail stores, etc. The big Genetec community ( &gt; 1200 employees around the world) is pretty unique and distributed across mostly Europe and Canada. We try to be one big group, eg. every year, we all come together at the YEP ( Year-End Party) in Montreal. There are also a lot of internal growth opportunities. We have the following job opportunities: - C#, Azure (in Canada &#x2F; Paris) - TypeScript and ReactJS ( in Canada) - Android ( Java ) or iOS ( Swift) ( in Canada) - Dynamics CRM ( in Canada) For more information, including how to apply: h					63	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good fit due to its remote work option, entry-level experience requirements, and use of Swift, but lacks clear information on iOS product and salary.	f			2026-05-08 17:06:22.197+00
122	2026-05-03 16:52:32.734324+00	Arc.dev	https://arc.dev/remote-jobs/j/aubay-portugal-software-engineer-in-test-appium-ombu6t2ped	594b438421107feddbc65fb2c64bfb4d	Aubay Portugal	Software Engineer in Test - Appium	Remote	Yes	Unknown		ios, swift	Aubay Portugal Software Engineer in Test - Appium Full-time Swift Testing Automation Software Development Innovation Data Support Test Automation Java JavaScript Banking Kotlin Continuous Integration Mobile App Development Integration Testing Team Building Community management Analysis Compliance Appium XCUITest Espresso Api testing CI/CD Private Pilot CLI Remote - Portugal, Portugal New					35	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 0, "experience_match": 0}	This internship opportunity is a good fit due to its remote work option and iOS relevance, but lacks information on experience requirements, salary, product quality, and visa sponsorship.	f			2026-05-08 16:53:24.201798+00
93	2026-04-28 20:40:27.319801+00	Arc.dev	https://arc.dev/remote-jobs/j/our-easy-game-tutoring-llc-ui-ux-designer-professional-in-educational-mobile-apps-okt6ms2w0v	a86c77f1115b2edbe261bf34deada33e	Our Easy Game Tutoring LLC	UI/UX Designer (Professional in Educational Mobile Apps)	Remote	Yes	Unknown		ios, swift	Our Easy Game Tutoring LLC UI/UX Designer (Professional in Educational Mobile Apps) Freelance iOS Ux writing Wireframing/prototyping Android Design Systems Testing Product design User flows Project management Research User Research UX design User journey mapping Payment systems Marketing strategies Data analytics Visual design UI design Mobile App Development Figma Advance prototyping Interactive Prototyping A/B testing Gameplay Social media engagement e-learning tools Remote - Lebanon 3 days ago					63	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its remote work option, entry-level experience requirements, and use of Swift and iOS technologies.	f			2026-05-08 16:55:32.82177+00
92	2026-04-28 20:40:27.319801+00	Arc.dev	https://arc.dev/remote-jobs/details/mobile-app-developer-ww-pt-ogi9xnc8at	535bccc513ff2ab40bdd5bdfbde28dfe	Arc ExclusiveFast apply	Mobile App Developer WW-PT	Remote	Yes	Unknown		ios, swift	Arc Exclusive Fast apply Mobile App Developer WW-PT Freelance Senior Hourly rate iOS Apple healthkit React Remote anywhere Actively hiring					35	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 0, "experience_match": 0}	This internship opportunity is a good fit due to its remote work option and iOS relevance, but lacks information on experience requirements, product quality, salary, and visa sponsorship.	f			2026-05-08 16:55:40.312463+00
38	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=12640049	6b2b010439e5e05db46801b4e0900b00	Darby Smart is looking for a Sr. iOS Engineer to join our team! Our mission is to make discovering and sharing your own creativity, simple and fun.At high level, the person who takes this role on woul	iOS Engineer	See post	Unknown	Unknown		swift	Darby Smart is looking for a Sr. iOS Engineer to join our team! Our mission is to make discovering and sharing your own creativity, simple and fun. At high level, the person who takes this role on would lead development of our user generated video iOS app, is responsible for its architecture and is excited about mentoring junior iOS engineers. SWIFT San Francisco CA ONSITE Email: casey@darbysmart.com					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, remote work uncertainty, and entry-level experience requirements, but lacks clear information on salary, visa sponsorship, and product quality.	f			2026-05-08 17:03:23.432676+00
36	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=41426962	a9b4457ea5201dc5c558981f251407e8	Midnite	Full Time	Remote (UK)	Yes	Unknown	no experience		Midnite | Full Time | Remote (UK) | https:&#x2F;&#x2F;www.midnite.com&#x2F;jobs Midnite is a next-generation betting platform that is built for today’s fandom. We are a collective of engineers and designers who all share a passion for building the best sportsbook &amp; casino experience possible. We are hiring across multiple roles: - Backend Engineer - https:&#x2F;&#x2F;apply.workable.com&#x2F;midnite&#x2F;j&#x2F;FFAA2713D3&#x2F; - Junior Backend Engineer - https:&#x2F;&#x2F;apply.workable.com&#x2F;midnite&#x2F;j&#x2F;CC0C6DF5C6&#x2F; - iOS Engineer - https:&#x2F;&#x2F;apply.workable.com&#x2F;midnite&#x2F;j&#x2F;834FBB445D&#x2F; - Junior iOS Engineer - https:&#x2F;&#x2F;apply.workable.com&#x2F;midnite&#x2F;j&#x2F;0ECC18C9A8&#x2F; Please mention hacker news in your cover letter!					48	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 0, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good fit due to its remote work option, entry-level experience requirements, and small startup nature, but lacks clear iOS relevance and salary information.	f			2026-05-08 17:03:40.530559+00
31	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=9308658	efde0581833c4f44759660ff864a6c1b	UN ESCAP - Java, Android, iOS and Moodle developers - Bangkok, ThailandESCAP is is the regional development arm of the United Nations for the Asia-Pacific region. Learn more about ESCAP at www.unescap	iOS Engineer	See post	Unknown	Unknown		swift, objc	UN ESCAP - Java, Android, iOS and Moodle developers - Bangkok, Thailand ESCAP is is the regional development arm of the United Nations for the Asia-Pacific region. Learn more about ESCAP at www.unescap.org We are still building and maintaining several web applications in Java for UN internal usage. We are also adding native Android and iOS mobile applications that interacts with these services. And doing elearning platforms on Moodle. We are looking for Java software developers and Android developers and IOS developers and Moodle developers, to join our Software Development team, as full-time position. On the java side, we mainly do Spring MVC webapps, with &quot;traditional&quot; front-end in HTML5, jQuery and Bootstrap. We deploy on Linux, so a familiarity with it is a plus. On iOS, we a					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, remote work uncertainty, and entry-level experience requirements, but lacks clear salary and visa sponsorship information.	f			2026-05-08 17:04:21.426705+00
42	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=16737719	6c40c75000080b105c07e1c312fce82c	Seedling	Los Angeles, CA	Mobile Developer - iOS	Unknown	Unknown		swift	Seedling | Los Angeles, CA | Mobile Developer - iOS | Onsite | https:&#x2F;&#x2F;www.seedling.com&#x2F; Seedling is looking for a junior to mid-level iOS engineer! We&#x27;re an AR&#x2F;VR toy company in Los Angeles, with a focus on merging physical and digital play. We&#x27;re looking to expand our suite of apps and features, all with an AR-focus (and all written in Swift). Our flagship product today is an AR teddy bear (Parker) sold in all Apple stores and various other retailers around the world. Apply: https:&#x2F;&#x2F;www.jsco.re&#x2F;1vcjp					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, remote work uncertainty, and junior-level experience requirements, but lacks clear information on salary and visa sponsorship.	f			2026-05-08 17:02:58.35036+00
40	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=31587443	0e397432e3b93cf472d65111d5d505da	NFCtron	Junior Frontend/Backend/iOS/Android Engineer	Prague, Czechia	Unknown	Unknown		swift, swiftui, combine	NFCtron | Junior Frontend&#x2F;Backend&#x2F;iOS&#x2F;Android Engineer | Prague, Czechia | Part-time ONSITE | Czech language required NFCtron is a well estabilished fintech startup. We develop NFC cashless payment system, analytic platform and a ticket portal for festivals and long-term events. Currently participating in 300+ events in Czechia and slowly expanding abroad. https:&#x2F;&#x2F;www.nfctron.com Looking for: - Junior Frontend Engineer (React, Next.js, TSX, TailwindCSS): admin console, real-time sales dashboard, ticket portal - Junior Backend Engineer (Node.js, Nest.js, TS, REST, PostgreSQL): REST API, SQL analytics, real-time data ingestion from POS devices, automated financing - iOS&#x2F;Android Engineer (SwiftUI, Combine, Flutter, Kotlin): POS app, NFC smartcards, end-customer a					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, remote work uncertainty, and junior-level experience requirements, but lacks clear information on salary, visa sponsorship, and iOS product confirmation.	f			2026-05-08 17:03:14.660125+00
98	2026-04-28 20:40:27.319801+00	Arc.dev	https://arc.dev/remote-jobs/j/crossing-hurdles-ux-designer-65-hr-remote-okaz7bo3sq	c48c7ffced19add66bc996b2f355d9d9	Crossing Hurdles	UX Designer | $65/hr Remote	Remote	Yes	Unknown		ios, swift, salary:$65/hr	Crossing Hurdles UX Designer | $65/hr Remote Freelance Swift Web Development UX design React Vue.js Bootstrap SQL Java jQuery Amazon EC2 Scala Algorithm Cloud Apache Spark E-commerce Research User Research Interface Design Data Apache Kafka System design Network Windows Application AI Communications Remote - Canada 3 days ago					65	{"visa": 0, "remote": 20, "salary": 10, "ios_relevance": 15, "product_quality": 0, "experience_match": 20}	This internship opportunity is a good match due to its remote work option, clear experience requirements, and specified salary, but lacks clear information about the iOS product and company.	f			2026-05-08 16:56:09.684927+00
95	2026-04-28 20:40:27.319801+00	Arc.dev	https://arc.dev/remote-jobs/j/nextdoor-software-engineer-ios-okt0u2lzlp	e5041fc1439230bced1976542ebcb441	Nextdoor	Software Engineer - iOS	Remote	Yes	Unknown		ios, swift, xcode	Nextdoor Software Engineer - iOS Full-time iOS Software Development Testing Network Swift Xcode Data analytics Community management Mobile App Development Infrastructure Data Analysis Project documentation Team Building AI Automated Tests Accessibility Experimentation Modular Code App ux design Design Patterns Team collaboration Remote - United States 3 days ago					43	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 0}	This internship opportunity is a good fit due to its remote work option and iOS relevance, but lacks clear experience requirements and salary information.	f			2026-05-08 16:56:24.716905+00
81	2026-04-28 11:07:28.46273+00	Arc.dev	https://arc.dev/remote-jobs/j/the-judge-group-product-designer-native-mobile-experiences-okt6pc5jmr	478e1145dfc7b38e67ee4a71a60f7adc		Product Designer - Native Mobile Experiences	Remote	Yes	Unknown		ios, swift	The Judge Group Product Designer - Native Mobile Experiences Freelance iOS Android Product design Web Development Mobile UI Design Systems Design Architecture Team collaboration Ux writing Support User flows Banking Scalability Material Design UX/UI Design Wireframing/prototyping Mentoring Financial Markets Accessibility for mobile Platform User Testing Leadership Remote - United States 2 days ago					55	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 0, "experience_match": 20}	This internship opportunity is a good match due to its remote work option, entry-level experience requirements, and iOS relevance, but lacks clear product quality and salary information.	f			2026-05-08 16:57:25.362891+00
24	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=13302988	cd427720603ef40dc85ed9d8a918b2d3	ŌURA	http://ouraring.com	Software Engineers: Python, Android, iOS	Unknown	Unknown		swift, salary:$5	ŌURA | http:&#x2F;&#x2F;ouraring.com | Software Engineers: Python, Android, iOS | Helsinki or Oulu, Finland | Onsite Are you ready? ŌURA ring is a wellness ring that measures your sleep, activity, temperature and heart rate and answers how ready you are for day&#x27;s challenges. Should you push yourself or take it easy? Our sleep analysis is world class and rings are already used in several on-going studies by leading research institutes. We had a successful Kickstarter in late 2015, ramped up production in 2016, have active user-base and growing sales. We just closed $5M A-round for growing the team and international expansion. We are looking for talented developers for following 3 positions: - Backend Developer (Python, AWS) https:&#x2F;&#x2F;ouraring.com&#x2F;career&#x2F;backend-develo					53	{"visa": 0, "remote": 0, "salary": 10, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, remote work uncertainty, and clear experience requirements, but lacks remote work confirmation and explicit visa sponsorship.	f			2026-05-08 17:02:09.016449+00
23	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=14239393	2f80279b41ca649b4ac4b1571dd42d1d	Sift	Detroit, MI	Fulltime and interns	Unknown	Unknown		swift	Sift | Detroit, MI | Fulltime and interns | ONSITE At Sift, we build applications to help organizations better understand their people. We want organizations to feel more like closely knit teams, where everyone supports each other to achieve their shared mission. We’re just 18-months old, but we’ve already secured 15,000+ users and over 20 clients. We’re proud to have Quicken Loans, an organization built on the foundation of a strong culture, using our apps to better understand who makes up their amazing team. React Native (Android) iOS (Swift) Backend Node.js Front End React Sounds interesting? Shoot me an email! Mat P, CTO, matp@justsift.com					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, remote work uncertainty, and entry-level experience requirements.	f			2026-05-08 17:02:16.537894+00
16	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=20868563	d236d811e3deb389476c7de4c03dbd09	Mercury	iOS Swift, React+Typescript, Haskell or generalist Software Engineer	San Francisco, CA	Unknown	Unknown		swift, salary:$6	Mercury | iOS Swift, React+Typescript, Haskell or generalist Software Engineer | San Francisco, CA | Full-time | ONSITE Mercury (mercury.co) is building a bank for startups. We are currently 14 people (8 engineers, 1 designer, 5 BD&#x2F;Ops) and have raised $6m from a tier A VC (A16Z). We launched 4 months ago and have 2k+ happy customers. This is my 4th company. My previous company, Heyzap, was YC09, was funded by USV and was acquired for $45m. Backend: Haskell Frontend: React&#x2F;Redux&#x2F;Typescript&#x2F;iOS&#x2F;Android Infra: NixOS, AWS We like generalist engineers and happy to hire smart people that are willing to learn. My email in profile or email jobs AT mercury DOT co. Also hiring for Accounts, Marketing, engineering interns and other roles. Learn more: https:&#x2F;&#x2F;mercur					53	{"visa": 0, "remote": 0, "salary": 10, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, suitable experience requirements, and a clear salary, but lacks remote work confirmation and explicit iOS product confirmation.	f			2026-05-08 17:02:25.136893+00
9	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=34612703	d2cc5d49c8d047121d83740cb8ba02bf	FAIRTIQ	REMOTE & flexible in European time zone	80-100%	Yes	Unknown		swift	FAIRTIQ | REMOTE &amp; flexible in European time zone | 80-100% | FAIRTIQ ( https:&#x2F;&#x2F;fairtiq.com&#x2F;en&#x2F; ) is the leading software solution that disrupts public transport ticketing. We use innovative algorithms to detect user journeys using data collected by mobile sensors. Since the founding in 2016, our innovative, simple solution has been recognised internationally. Thanks to our strategic partnerships, we already cover the entire public transportation system in Switzerland – while also growing internationally, i.e. in Germany, Austria and other regions. Tech stack: * Architecture principles: Microservices, Continuous Integration &amp; Delivery, Domain Driven Design, MVVM, Hexagonal architecture, Zero downtime * Programming languages we use: iOS - Swift, Android - Kotlin&					63	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good fit due to its remote work option, experience match, and tech stack, but lacks clear information on iOS product and salary.	f			2026-05-08 17:02:33.634424+00
33	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=8123568	ab98f19f6e17673c3b3c04fd92bd6cd6	Lucid Software (http://www.golucid.co) is building world class graphical applications in the browser and on mobile devices. Our first product, Lucidchart (http://www.lucidchart.com), is an online diag	iOS Engineer	See post	Unknown	Unknown	2+ years	objective-c	Lucid Software ( http:&#x2F;&#x2F;www.golucid.co ) is building world class graphical applications in the browser and on mobile devices. Our first product, Lucidchart ( http:&#x2F;&#x2F;www.lucidchart.com ), is an online diagramming application with 1M+ users. We recently launched our second product, Lucidpress ( http:&#x2F;&#x2F;www.lucidpress.com ), which is an online layout and design application. Lucid is a startup founded by Karl Sun, a former Google exec, and Ben Dilts, our CTO. We&#x27;ve been profitable for 2+ years and recently closed our Series A. We are growing rapidly in every dimension of the business and need people to join our team. For fun we raft river rapids on company retreats, have Friday BBQs, and eat lots of pizza. Talent and ability to learn are more important than sp					0	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 0, "product_quality": 0, "experience_match": 0}	This job opportunity does not match the candidate's requirements due to lack of iOS relevance, remote work, and experience match.	f			2026-05-08 17:01:44.18558+00
30	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=9519142	6e1d0d9c578a559e2b93d6cfb3778fa3	http://www.stryd.com, Boulder, CO	Intern	iOS DeveloperAthlete Architect is a multidisciplinary team that is enthusiastic about the future of wearable technology for athletes. Out of this passion, we've developed the world’s first wearable po	Unknown	Unknown		swift, objective-c	http:&#x2F;&#x2F;www.stryd.com , Boulder, CO | Intern | iOS Developer Athlete Architect is a multidisciplinary team that is enthusiastic about the future of wearable technology for athletes. Out of this passion, we&#x27;ve developed the world’s first wearable power meter, Stryd, for runners that provides insight into their running technique and performance. For the iOS development, we use Swift primarily. But we want you to have deep understanding of Objective-C and the best practices of iOS programming. Good sense of design is bonus. We also want you to be an endurance runner, or a triathlete, or at least to have passion about running. Relocate to Boulder during the internship is required. But you know what? If you like running, this is pretty much your dream place. You get tons of opport					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, remote work uncertainty, and entry-level experience requirements, but lacks clear information on salary and visa sponsorship.	f			2026-05-08 17:01:51.791042+00
37	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=36712730	87757cdada48133fedcfddc9a7ef6221	SwiftKick Mobile	iOS Engineer	W2 Contract, 6 months with strong probability of extension	Hybrid	Unknown	1-2 years	swift, swiftui, salary:$90k-$120k	SwiftKick Mobile | iOS Engineer | W2 Contract, 6 months with strong probability of extension | Hybrid in Austin, TX SwiftKick is a boutique mobile development agency based in Austin, TX. Some of our past clients include Expedia&#x2F;Vrbo, Experian, and Sysco Labs. We&#x27;re looking for a junior-level iOS Engineer with some practical experience (e.g. a portfolio, or 1-2 years of work experience) or someone midlevel (2-4 YOE) to work directly with our chief engineer to overhaul an existing app with new designs. SwiftUI experience is a must have. The anticipated salary range is ~$90k-$120k&#x2F;year with benefits. If interested, please send your resume directly to connor@swiftkickmobile.com.					43	{"visa": 0, "remote": 0, "salary": 10, "ios_relevance": 15, "product_quality": 8, "experience_match": 10}	This internship opportunity scores moderately due to its hybrid remote setup, specific salary range, and iOS relevance, but lacks clear confirmation of iOS product and visa sponsorship.	f			2026-05-08 17:08:02.151122+00
110	2026-04-30 10:15:47.087131+00	Arc.dev	https://arc.dev/remote-jobs/j/motion-recruitment-software-engineer-in-test-lnqta3in21	1a05a0c93d04cb6e2cb06e237d084a7f	Motion Recruitment	Software Engineer in Test	Remote	Yes	Unknown		ios, swift	Motion Recruitment Software Engineer in Test Freelance Swift Testing Automation Software Development Git Continuous Integration QA Java Python Kotlin Functional Programming Amazon Version control Cloud Test Automation AI Docker Design Architecture Kubernetes Analysis Nginx Support Jira Process automation Infrastructure CI/CD AWS Api testing pytest Remote - North America New					55	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 0, "experience_match": 20}	This internship opportunity is a good fit due to its remote work option, match with the intern's experience level, and the use of Swift in the tech stack, but lacks clear information about the iOS product and salary.	f			2026-05-08 16:54:32.73065+00
13	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=28720352	ba0fa9cad6d081f02b8e5c8e7201ddd2	onXmaps, Inc	Montana or REMOTE, USA only	https://www.onxmaps.com/careersABOUT – Are you an Engineer who loves the outdoors? Join onX! onX is a suite of digital navigation apps (Hunt, Offroad, and Backcountry) that empower millions of outdoor	Yes	Unknown		swift, swiftui, combine	onXmaps, Inc | Montana or REMOTE, USA only | https:&#x2F;&#x2F;www.onxmaps.com&#x2F;careers ABOUT – Are you an Engineer who loves the outdoors? Join onX! onX is a suite of digital navigation apps (Hunt, Offroad, and Backcountry) that empower millions of outdoor enthusiasts. If you’re passionate about writing great software, love playing outside, believe in protecting access to public lands, and want to dominate the off-pavement mobile GPS market – then join our team, where we empower millions of outdoor enthusiasts to explore the unknown! We have multiple openings! View them here: https:&#x2F;&#x2F;www.onxmaps.com&#x2F;join-our-team Here are some of the technologies we work with: Data Automation (Python, PostgreSQL, PostGIS, GIS) Android (Kotlin, ReactiveX) iOS (Swift, SwiftUI, Combine) Ba					43	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 0}	This internship opportunity is a good fit due to its remote work option and iOS relevance, but lacks information on experience requirements and salary.	f			2026-05-08 17:07:37.602821+00
51	2026-04-23 11:44:52.136775+00	Remotive	https://remotive.com/remote-jobs/software-development/ios-developer-1956455	8a47fbc7d3ef704021e98941a5e13623	nooro	iOS Developer	USA	Yes	Unknown		api, backend, git, ios, security, swift, UI/UX, Figma, agile, healthcare, swiftui	WHO ARE WE? At nooro, we're revolutionizing pain management for seniors. Our platform is transforming how older adults engage with pain management at home. We're on a mission to make wellness more accessible and effective through technology. Check our website here: https://nooro-us.com/ We're a fast-moving startup that works on quick iteration and bold decisions. Our team is lean, agile, and empowered to make meaningful impacts daily. If you enjoy a dynamic environment where ideas become a reality at lightning speed and you're not afraid to wear multiple hats, you'll fit right in. WHAT WILL YOU DO? - Own and drive the development of our iOS application - Build elegant, performant features using **Swift (We’re 100% Swift!)** and **SwiftUI** - Implement complex UI/UX designs from **Figma** w					43	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 0}	This internship opportunity is a good fit due to its remote work option and iOS relevance, but lacks clear experience requirements and salary information.	f			2026-05-08 17:07:53.6449+00
123	2026-05-05 10:39:29.242597+00	Arc.dev	https://arc.dev/remote-jobs/j/optomi-design-systems-lead-product-designer-omkoaskw4w	bd491df90bd51156ab5e8aaafbd44358	Optomi	Design Systems Lead (Product Designer)	Remote	Yes	Unknown		ios, swift	Optomi Design Systems Lead (Product Designer) Freelance Lead iOS Design Systems Research Automation Project documentation Responsive Design Web Development Scalability AI Support Growth Compliance Figma Storybook Remote - United States New					63	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good fit due to its remote work option, match with the intern's experience level, and the use of Swift and iOS in the tech stack, but lacks clear information on salary and iOS product quality.	f			2026-05-08 16:52:00.80126+00
128	2026-05-06 15:42:07.974055+00	Google Jobs	https://jobs.ashbyhq.com/bliro	382d064b7c3e8bd7f0c074a21b559a23		Bliro GmbH - Jobs		Hybrid	Unknown		swift	Founder's Associate Intern - Product (f/m/d). Product & Engineering • Munich Office • Intern • Hybrid · Founding Engineer - iOS & Swift (f/m/d). Product ...					35	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 0, "experience_match": 0}	This internship opportunity is a good fit due to its hybrid remote work arrangement and explicit mention of Swift, but lacks clear information on experience requirements and salary.	f			2026-05-08 16:51:07.53522+00
68	2026-04-27 06:24:59.943714+00	Arc.dev	https://arc.dev/remote-jobs/j/nextdoor-software-engineer-ios-okt0u2lzlp	ae754c102c02699400c45c3a02c7ad52		Software Engineer - iOS	Remote	Yes	Unknown		ios, swift, xcode	Nextdoor Software Engineer - iOS Full-time Swift iOS Software Development Testing Network Xcode Data analytics Community management Mobile App Development Infrastructure Data Analysis Project documentation Team Building AI Automated Tests Accessibility Experimentation Modular Code App ux design Design Patterns Team collaboration Remote - United States a day ago					63	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good fit due to its remote work option, entry-level experience requirements, and focus on iOS development, but lacks clear information on salary and product funding.	f			2026-05-08 16:58:47.967991+00
69	2026-04-27 06:24:59.943714+00	Arc.dev	https://arc.dev/remote-jobs/j/crossing-hurdles-ux-designer-65-hr-remote-okaz7bo3sq	afea868886d8d5b02b490d38b6ab7b3a		UX Designer | $65/hr Remote	Remote	Yes	Unknown		ios, swift, salary:$65/hr	Crossing Hurdles UX Designer | $65/hr Remote Freelance Swift Web Development UX design React Vue.js Bootstrap SQL Java jQuery Amazon EC2 Scala Algorithm Cloud Apache Spark E-commerce Research User Research Interface Design Data Apache Kafka System design Network Windows Application AI Communications Remote - Canada a day ago					65	{"visa": 0, "remote": 20, "salary": 10, "ios_relevance": 15, "product_quality": 0, "experience_match": 20}	This internship opportunity is a good match due to its remote work option, clear experience requirements, and specified compensation, but lacks clear iOS product confirmation and funding information.	f			2026-05-08 16:58:55.480182+00
55	2026-04-26 16:43:44.294829+00	WeWorkRemotely	https://weworkremotely.com/remote-jobs/infinity-founding-product-engineering-lead-radiance	26b61ec91819b79302b5778fb05a2966	Infinity	Founding Product & Engineering Lead - Radiance	Remote	Yes	Unknown		combine	Headquarters: Remote Meet Radiance The Source® of all your creative collateral. Radiance is a digital design agency powered by The SOURCE® , a proprietary Creative OS that aligns every asset, message, and moment into one adaptive brand system. We combine human-crafted design with intelligent systems to help modern brands operate with clarity, speed, and cohesion. Every engagement we deliver is not just creative output, but infrastructure : systems that scale as our clients grow. At the center is The SOURCE® , a platform blending design, AI, and automation into a single evolving system for brand truth, execution, and growth. We are backed by Infinity Constellation , the first AI holding company, and are building something category-defining at the intersection of brand, systems, and intellig					63	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good fit due to its remote work option, entry-level experience requirements, and clear mention of iOS, but lacks specific salary information and clear iOS product confirmation.	f			2026-05-08 17:00:05.732859+00
57	2026-04-26 16:43:44.294829+00	WeWorkRemotely	https://weworkremotely.com/remote-jobs/treehouse-job-board-electrical-design-lead	8253bda4300699f3ab3494511385bf5f	Treehouse Job Board	Electrical Design Lead	Remote	Yes	Unknown		combine	Headquarters: Chicago, IL About Treehouse&nbsp; Treehouse is an electrical contractor committed to accelerating the decarbonization of the places we live and work. By operating as a centralized, end-to-end partner, Treehouse helps companies scale electrification programs and delivers seamless, delightful installation experiences for customers . About the Role This role is ideal for a highly skilled Journeyman Electrician who is ready to move beyond the field and into design and enablement. The Electrical Design Lead is responsible for ensuring the electrical scope of every project is technically sound, code-compliant, and ready for execution. This role provides scoping oversight, supports pre-sale technical review, and helps prepare every job for a smooth, high-quality install. The ideal c					28	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 0, "product_quality": 8, "experience_match": 0}	This internship opportunity is mostly attractive due to its remote work option, but lacks clear iOS relevance and experience requirements.	f			2026-05-08 17:00:14.472601+00
59	2026-04-26 16:43:44.294829+00	Arc.dev	https://arc.dev/remote-jobs/j/ltm-software-engineer-okaxl60aos	4d6062691dd1aaa7e2a0f20f109259b2		LTM Software Engineer Freelance iOS React React Native Android Testing DevOps Data Redux Software De	Remote	Yes	Unknown		swift, xcode, objective-c	LTM Software Engineer Freelance iOS React React Native Android Testing DevOps Data Redux Software Development Web Development Graphql.js Hardware TypeScript Support SQLite Xcode Automation Unit Testing Continuous Integration Azure Firebase Security software MobX Jest Marketing strategies Analysis Ux writing Operations IoT System security Java Kotlin Objective-C Swift RESTful API GraphQL OAuth 2.0 Jwt Realm Fastlane Bitrise Detox Appium Crashlytics Sentry SAP Fiori Bluetooth Remote - Brazil New					63	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good fit due to its remote work option, entry-level experience requirements, and iOS relevance, but lacks clear information on salary and product quality.	f			2026-05-08 17:00:22.025009+00
12	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=29072219	fea158a727b8a03b275feb06b8d0cd94	Lisa Health	Part-Time Intern	Remote	Yes	Unknown		swift, salary:$13	Lisa Health | Part-Time Intern | Remote | US Only Lisa Health is transforming midlife women&#x27;s health starting with menopause, a life stage every woman will experience, and a $13B global market opportunity. Our digital health solution is bridging the gap in care with a precision medicine platform using patent-pending sensor-enabled, machine learning algorithms that can detect and monitor menopause and aging biomarkers and deliver personalized treatment. We are looking for a software engineer to participate in a National Science Foundation (NSF) SBIR Seed Fund Phase 1 grant project. You will work on integrating an FDA-cleared, medical-grade wearable device with an IOS mobile app and a proprietary algorithm to detect women&#x27;s health biomarkers. This is an excellent opportunity to wor	Ann Garnier	Lisa Health - LinkedIn	https://www.linkedin.com/in/anngarnier		73	{"visa": 0, "remote": 20, "salary": 10, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good fit due to its remote work option, match with the intern's experience level, and clear salary, but lacks explicit confirmation of iOS product and Swift/SwiftUI usage.	f			2026-05-08 20:36:16.67875+00
74	2026-04-28 11:07:28.46273+00	Google Jobs	https://jobs.lever.co/matchgroup/178e6f99-ddbb-43e1-9e4c-fe2b524e0861	b36f38c43a9f25b4d7cb551d255e2cef	Match Group	iOS Engineer Intern		Unknown	Unknown		swift	What we're looking for: Aspiring iOS developer who's excited to work on large scale challenges with cutting-edge technology. Proficiency in coding with Swift.					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, remote work uncertainty, and the required experience level, but lacks information on salary, product quality, and visa sponsorship.	f			2026-05-08 16:57:48.082117+00
76	2026-04-28 11:07:28.46273+00	Google Jobs	http://job-boards.eu.greenhouse.io/proton/jobs/4741036101	080cbeb4b38fa419c5a8a40665c14147	Proton	iOS Software Engineer Intern		Unknown	Unknown			We're looking for an iOS Developer Intern to help build and launch a brand-new iOS application from the ground up. You'll work closely with senior iOS ...					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	A decent internship opportunity with a relatively unknown remote status and unclear compensation, but a good match for an entry-level iOS developer.	f			2026-05-08 16:58:09.993492+00
82	2026-04-28 11:07:28.46273+00	Arc.dev	https://arc.dev/remote-jobs/j/presage-technologies-software-engineer-c-okt1zuuf24	de326c5f0e78e34a352faa3c901cc547		Software Engineer (C++)	Remote	Yes	Unknown		ios, swift	Presage Technologies Software Engineer (C++) Full-time iOS Software Development C++ Testing React React Native Android QA Flutter Mobile App Development Data analytics AI Wireframing/prototyping Continuous Integration Version control Concurrent Programming Windows Application macOS Engineering Management Debugging Performance Optimization CI/CD Remote - United States 2 days ago					55	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 0, "experience_match": 20}	This internship opportunity is a good fit due to its remote work option, match with the intern's experience level, and mention of Swift in the tech stack, but lacks clear information about the iOS product and salary.	f			2026-05-08 16:58:33.805019+00
56	2026-04-26 16:43:44.294829+00	WeWorkRemotely	https://weworkremotely.com/remote-jobs/addepto-product-owner-technical-background	1938d973aa731df167b06eb3ce4cefe0	Addepto	Product Owner (Technical Background)	Remote	Yes	Unknown		combine	Headquarters: Krucza 50 Warszawa, 14, 00-025 Poland Job description Addepto is a leading AI consulting ( https://addepto.com/ai-consulting/ ) and data engineering ( https://addepto.com/data-engineering-services/ ) company that builds scalable, ROI-focused AI solutions for some of the world's largest enterprises and pioneering startups, including Rolls Royce, Continental, Porsche, ABB, and WGU. With an exclusive focus on Artificial Intelligence and Big Data, Addepto helps organizations unlock the full potential of their data through systems designed for measurable business impact and long-term growth. The company's work extends beyond client engagements. Drawing from real-world challenges and insights, Addepto has developed its own product - ContextClue - and actively contributes open-sourc					48	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 0, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good fit due to its remote work option, entry-level experience requirements, and small startup nature, but lacks clear iOS relevance and salary information.	f			2026-05-08 17:00:29.683364+00
90	2026-04-28 20:40:27.319801+00	Google Jobs	https://jobs.ashbyhq.com/gen-digital	a7dfa2ef52732484e9b1051dfc05eccb		Gen Digital Inc. - Jobs		Unknown	Unknown		swift	MacOS Swift Software Engineer. Development • CZE - Brno; CZE - Prague • Full ... Software Engineering Intern (Summer Internship). Technology • CZE - Brno ...					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, remote work uncertainty, and suitable experience requirements, but lacks clear information on salary, product quality, and visa sponsorship.	f			2026-05-08 16:55:55.556709+00
87	2026-04-28 20:40:27.319801+00	Google Jobs	https://jobs.ashbyhq.com/chainlink-labs/c71ed144-8eb4-4acf-9bf3-137b1b067ed8	ea235d4498f730fa4ebfac58c0d8ecc9		Chainlink Labs - Research Internship - Jobs		Unknown	Unknown		swift	Intern. Location ... Many of the world's largest financial services institutions have also adopted Chainlink's standards and infrastructure, including Swift ...					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	A decent opportunity with a good experience match, but unclear remote and salary information, and limited iOS product confirmation.	f			2026-05-08 16:56:02.099057+00
85	2026-04-28 20:40:27.319801+00	Google Jobs	https://jobs.ashbyhq.com/sieve/2298668b-f218-435a-a497-de4fc11c5ac6	be535cc15c74a32da1cbe726d9e516a6	Sieve - Jobs	Applied Research Engineering Intern		Unknown	Unknown		swift	... Swift Ventures, Y Combinator, and AI Grant. About the Role. As an applied research engineering intern at Sieve, you'll help build high performance building ...					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, remote work uncertainty, and entry-level experience requirements, but lacks clear information on salary, visa sponsorship, and iOS product confirmation.	f			2026-05-08 16:56:32.541907+00
88	2026-04-28 20:40:27.319801+00	Google Jobs	https://jobs.ashbyhq.com/sana-roles/c364e995-17be-4716-b93a-26bf9eb6ff2d?action=apply	124abf76ee74d67b7b5e9e06f5ee5651	Sana - Jobs	Summer Sanian		Unknown	Unknown		swift	Swift professional growth in an evolving environment, supported by a culture of continuous feedback and mentorship from senior leaders. Work with talented ...					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, remote work uncertainty, and suitable experience requirements, but lacks clear information on salary, product quality, and visa sponsorship.	f			2026-05-08 16:56:40.076984+00
86	2026-04-28 20:40:27.319801+00	Google Jobs	https://jobs.ashbyhq.com/nord-security/b20ff537-d333-4f3d-b1c1-aa141048e030	1bbe1fe99d44a632069eeb71e60a8001		Agentic Product Engineer | Internship | Full-stack | Saily - Jobs		Unknown	Unknown		swift, swiftui, xcode, combine, spm	... SwiftUI, Xcode, Combine, SPM, MVVM Architecture - Android: Kotlin, Android ... Agentic Product Engineer | Internship | Full-stack | Saily. Location. Vilnius ...					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development and the fact that it's an internship, but lacks clear information on remote work, salary, and product quality.	f			2026-05-08 16:56:47.542726+00
73	2026-04-28 11:07:28.46273+00	HackerNews	https://news.ycombinator.com/item?id=20332896	1339e1012ad0276d7614f9814804f4e7	Craftnote	Engineering	Berlin, Germany	Yes	Unknown		swift	Craftnote | Engineering | Berlin, Germany | ONSITE &amp; REMOTE Craftnote offers a mobile app and SaaS solution for the construction business. We always work customer-focussed, are technologically strong and open for innovation. As corporate start-up of fischer group Germany, we enjoy both the agility of a small &amp; independent team as well as the experience and stability of a large corporation. Available positions: - Senior Mobile Developer Android (Java&#x2F;Kotlin) - Senior Mobile Developer iOS (Swift) - Senior Mobile Developer Web (Angular) - Junior Mobile Developer Android (Java&#x2F;Kotlin) - Junior Mobile Developer iOS (Swift) - Junior Mobile Developer Web (Angular) https:&#x2F;&#x2F;www.craftnote.de&#x2F;jobs Benefits: - Hardware of your choice - 30 days of vacation - Flexible wo					63	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good fit due to its remote work option, entry-level experience requirements, and use of Swift, but lacks clear iOS product confirmation and salary information.	f			2026-05-08 16:58:03.301069+00
67	2026-04-27 06:24:59.943714+00	Arc.dev	https://arc.dev/remote-jobs/j/openlane-ios-developer-oka8l1ksjv	f88015e175a11ce2753e1b1c8a04b259		iOS Developer	Remote	Yes	Unknown		ios, swift, uikit, objective-c, combine	OPENLANE iOS Developer Full-time iOS Testing Swift QA Continuous Integration Software Development Data AI Product design Mobile App Development Agile Innovation Team collaboration Git MvvmCross UIKit Ux writing Engineering Management UX design Support CAD Git flow Communications MVVM Clean Architecture RESTful API Combine Async.js Dependency Manager Xctest UI Testing CI/CD Objective-C Storyboards Tools Remote - Canada 3 days ago					63	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its remote work option, entry-level experience requirements, and focus on iOS development, but lacks clear information on salary and product funding.	f			2026-05-08 16:59:27.113972+00
54	2026-04-26 16:43:44.294829+00	WeWorkRemotely	https://weworkremotely.com/remote-jobs/speechify-inc-software-engineer-ios-core-product	66572f12a17a2836b807a776910d7d20	Speechify Inc	Software Engineer, iOS Core Product	Remote	Yes	Unknown		swift, swiftui	Headquarters: Florida URL: http://www.speechify.com Overview With the growth of our iOS app, being the #18 productivity app in the App Store category and also our recent recognition as Apple's 2025 Design Award for inclusivity, we find the need for a Senior iOS Engineer to help us support the new user base as well as work on new and exciting projects to push our missing forward. &nbsp;&nbsp; This is a key role and ideal for someone who thinks strategically, enjoys fast-paced environments, passionate about making product decisions, and has experience building great user experiences that delight users. We are a flat organization that allows anyone to become a leader by showing excellent technical skills and delivering results consistently and fast. Work ethic, solid communication skills, and					43	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 0}	This internship opportunity is a good fit due to its remote work option and iOS relevance, but lacks clear experience requirements and salary information.	f			2026-05-08 17:00:46.761674+00
60	2026-04-26 16:43:44.294829+00	Arc.dev	https://arc.dev/remote-jobs/j/crossing-hurdles-ux-designer-65-hr-remote-okaz7bo3sq	e16cab5c1148d516f388cc60ad4b17a4		Filters Filters: 1 Swift ​ Crossing Hurdles UX Designer | $65/hr Remote Freelance Swift Web Developm	Remote	Yes	Unknown		salary:$65/hr, swift	Filters Filters: 1 Swift ​ Crossing Hurdles UX Designer | $65/hr Remote Freelance Swift Web Development Ux writing React Vue.js Bootstrap SQL Java jQuery Amazon EC2 Scala Algorithm Cloud Apache Spark E-commerce Research User Research Interface Design Data Apache Kafka System design Network Windows Application AI Communications SkySpark Windows Server Remote Work Team collaboration Remote - United Kingdom, United Kingdom a day ago Crossing Hurdles Full Stack Developer | $65/hr Remote Freelance Sw					65	{"visa": 0, "remote": 20, "salary": 10, "ios_relevance": 15, "product_quality": 0, "experience_match": 20}	This internship opportunity is a good match due to its remote work option, entry-level experience requirements, and specified salary, but lacks clear iOS product confirmation and funding information.	f			2026-05-08 17:00:54.373582+00
32	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=9305194	9144a60313452814cee8c7eec74d062c	http://www.stryd.com, Boulder, COAthlete Architect is a multidisciplinary team that is enthusiastic about the future of wearable technology for athletes. Out of this passion, we've developed the world	iOS Engineer	See post	Yes	Unknown		swift, objective-c	http:&#x2F;&#x2F;www.stryd.com , Boulder, CO Athlete Architect is a multidisciplinary team that is enthusiastic about the future of wearable technology for athletes. Out of this passion, we&#x27;ve developed the world’s first wearable power meter, Stryd, for runners that provides insight into their running technique and performance. We&#x27;re looking to expand our still small engineering team of only 3 people. We&#x27;re looking for: #1 Lead iOS Developer. We use Swift. But we want you to have deep understanding of Objective-C and iOS programming best practices. Good sense of design is bonus. #2 Firmware Developer. You need to have knowledge of microcontroller-based firmware design and development. Experience with relevant technologies, such as BLE, hardware debugging, analog and digital 					43	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 0}	This internship opportunity is a good fit due to its remote work option and iOS relevance, but lacks clear experience requirements and salary information.	f			2026-05-08 17:04:05.248156+00
65	2026-04-27 06:24:59.943714+00	Arc.dev	https://arc.dev/remote-jobs/j/ltm-software-engineer-okaxl60aos	b4a46861432b734675efdf58dc319994		Software Engineer	Remote	Yes	Unknown		ios, swift, xcode, objective-c	LTM Software Engineer Freelance iOS React React Native Android Testing DevOps Data Redux Software Development Web Development Graphql.js Hardware TypeScript Support SQLite Xcode Automation Unit Testing Continuous Integration Azure Firebase Security software MobX Jest Marketing strategies Analysis Ux writing Operations IoT System security Java Kotlin Objective-C Swift RESTful API GraphQL OAuth 2.0 Jwt Realm Fastlane Bitrise Detox Appium Crashlytics Sentry SAP Fiori Bluetooth Remote - Brazil 2 days ago					35	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 0, "experience_match": 0}	This internship opportunity is a good fit due to its remote work option and iOS relevance, but lacks information on experience requirements, product quality, salary, and visa sponsorship.	f			2026-05-08 16:59:11.653528+00
58	2026-04-26 16:43:44.294829+00	Arc.dev	https://arc.dev/remote-jobs/details/swift-swiftui-developer-ohpx55yqj1	04b3cf936b5661c92d9ed0cc109dd399		Featured remote iOS jobs exclusive on Arc Explore opportunities from top companies actively hiring n	Remote	Yes	Unknown		swift, swiftui, xcode	Featured remote iOS jobs exclusive on Arc Explore opportunities from top companies actively hiring now. Our team supports you during the process, ensuring you stand out to our network of top startups and tech companies. Filters Filters: 1 iOS ​ Arc Exclusive Fast apply Swift/SwiftUI Developer Freelance Mid-level Hourly rate Swift Xcode Remote - United States Actively hiring Arc Exclusive Fast apply Mobile App Developer WW-PT Freelance Senior Hourly rate iOS Apple healthkit React Remote anywhere 					55	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 0, "experience_match": 20}	This internship opportunity is a good fit due to its remote work option, entry-level experience requirements, and relevant tech stack, but lacks clear information on the iOS product and salary.	f			2026-05-08 17:00:38.174066+00
5	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=9305024	66a10f8eb5f62fc58e9cd1e84b398d67	mPath	Palo Alto	Remote possible	Yes	Unknown		swift, objc	mPath | Palo Alto | Remote possible | RESTful APIs, Sinatra, react.js, Swift, J2Objc, iOS, Android, Dropwizard, Haskell etc. mPath is building a platform that allows regular folks to assemble native mobile apps via a drag and drop interface. We have our own data platform, but we connect to others, like Salesforce and Box.com. We&#x27;re focusing on internal productivity apps for the enterprise right now. We have a strong engineering, design and security focus. Opportunities include: Startup CTO (full stack experience; more doing than managing) Web UI Engineer (Sinatra &#x2F; React) iOS Engineer (Swift, j2Objc) Android Engineer (Java, j2Objc) Devops (Docker &#x2F; Jenkins &#x2F; AWS) Automation &#x2F; QA Engineer Check us out at: http:&#x2F;&#x2F;mpath.com&#x2F;careers					43	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 0}	This internship opportunity is a good fit due to its remote work possibility and iOS relevance, but lacks clear experience requirements and salary information.	f			2026-05-08 17:04:52.965458+00
7	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=40850475	a5ec6bf146e7e4d8ee81dd968b41c4f9	Stealth Mobility Company	Mobile Engineer (React Native) & Fullstack Engineer	CONTRACT	Yes	Unknown		swift, xcode	Stealth Mobility Company | Mobile Engineer (React Native) &amp; Fullstack Engineer | CONTRACT | REMOTE &amp; HYBRID | Los Angeles, CA We&#x27;re a stealth mode company based in California building the next generation of electric vehicles and worldwide mobility. We need motivated and broad-skilled software engineers who have experience in mobile app and full stack development. * Mobile Engineer (React Native) - Ideally candidates have deep experience developing and building native mobile applications (primarily with React Native) comfortable with Android Kotlin&#x2F;Java and&#x2F;or iOS Swift, and familiar with most common third party libraries and APIs, Javascript&#x2F;Typescript, mobile build tools (such as Gradle, Android Studio, and Xcode) and some interest or experience working with BL					63	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good fit due to its remote work option, entry-level experience requirements, and iOS-related tech stack, but lacks clear information on iOS product and salary.	f			2026-05-08 17:05:01.498462+00
49	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=30164958	a19b4afd8372cc80c3926fa7e1f9ad17	FreeAgent, Edinburgh and REMOTE U.K.	iOS Engineer	See post	Yes	Unknown		swift	FreeAgent, Edinburgh and REMOTE U.K. https:&#x2F;&#x2F;www.freeagent.com At FreeAgent we help freelancers and small businesses be more successful by putting them in control of their company finances. See our stack: https:&#x2F;&#x2F;stackshare.io&#x2F;freeagent&#x2F;freeagent We have built an award-winning banking and accounting app that offers full end-to-end compliance, from time tracking to tax return filing. We&#x27;re based in beautiful Edinburgh and we&#x27;re growing from strength to strength with over 120,000 paying customers and strong YoY growth. Our NPS is amazing (70!) - customers love what we do and our team get to make a real impact. We&#x27;re a team of over 250 people. 50% of our engineering team are distributed across the UK, the rest being based at our Edinburgh HQ (obvio					63	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its remote work option, entry-level experience requirements, and use of Swift, but lacks clear information on iOS product quality and salary.	f			2026-05-08 17:05:09.035908+00
11	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=30515827	4a9298c6aa1c4c745d27764aba702c4a	FreeAgent, Edinburgh and REMOTE U.K.	INTERNS	See post	Yes	Unknown		swift	FreeAgent, Edinburgh and REMOTE U.K. | INTERNS https:&#x2F;&#x2F;www.freeagent.com At FreeAgent we help freelancers and small businesses be more successful by putting them in control of their company finances. See our stack: https:&#x2F;&#x2F;stackshare.io&#x2F;freeagent&#x2F;freeagent We have built an award-winning banking and accounting app that offers full end-to-end compliance, from time tracking to tax return filing. We&#x27;re based in beautiful Edinburgh and we&#x27;re growing from strength to strength with over 130,000 paying customers and strong YoY growth. Our NPS is amazing (70!) - customers love what we do and our team gets to make a real impact. We&#x27;re a team of over 250 people. 50% of our engineering team are distributed across the UK, the rest being based at our Edinburg					63	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its remote work option, entry-level experience requirements, and use of Swift, but lacks clear information on iOS product and salary.	f			2026-05-08 17:05:17.57015+00
2	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=22225337	31d6954e7af2218cc7fa1d6fe916ca03	Muse	engineering partner	remote	Yes	Unknown		swift	Muse | engineering partner | remote | https:&#x2F;&#x2F;museapp.com Muse is an iPad app for research, deep thinking, and creativity. We&#x27;re a four-person team seeking an engineer to join as a ful partner in the business. You should be excited about high-performance software like video&#x2F;audio editing tools, game engines, or browser internals. Swift+iOS experience helpful but not required. Conference talk by a founder: https:&#x2F;&#x2F;www.youtube.com&#x2F;watch?v=A_fe2c6IUUo_ Article about our design approach: https:&#x2F;&#x2F;www.inkandswitch.com&#x2F;muse-studio-for-ideas.html Read more and apply here: https:&#x2F;&#x2F;museapp.com&#x2F;engineering-partner					63	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good fit due to its remote work option, entry-level experience requirements, and use of Swift, but lacks clear information on iOS product and salary.	f			2026-05-08 17:05:26.236993+00
22	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=14239796	b9cfe34ca00a78cfef645f5e8f0d3ab3	Prattle	Atlanta	Full Stack Engineer	Yes	Unknown		swift	Prattle | Atlanta | Full Stack Engineer | Internship, Remote | https:&#x2F;&#x2F;Letsprattle.com Prattle is creating the place where live conversations happen online. Our vision is to make real time conversations as accessible as finding a website on Google or a video on YouTube. We have two internship positions available and are looking for superheros who want to be apart of making the world a little better. If you&#x27;re looking for experience in the startup world and want to get your foot in the door this is a great opportunity for you. We are a fast growing company with a friendly and fun culture. So if you believe in diversity and want your creative input heard you will fit right in. Experience &amp; Knowledge | iOS, Android, Swift, PHP, EC2, Firebase and AWS Reach out and lets pratt					63	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its remote work option, entry-level experience requirements, and use of Swift, but lacks clear information on iOS product and salary.	f			2026-05-08 17:05:33.769948+00
27	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=7164841	653c828467193947315250d85bf9ca32	Layer - San Francisco, CALayer is building an open communications layer for the Internet: a globally-distributed communications network that enables app developers to quickly and easily build secure, 	iOS Engineer	See post	Yes	Unknown			Layer - San Francisco, CA Layer is building an open communications layer for the Internet: a globally-distributed communications network that enables app developers to quickly and easily build secure, scalable messaging, voice and video features into any app. Design Web Designer Engineering Android Developer Internship Android Engineer Backend Engineer iOS Developer Internship iOS Engineer Systems Engineer Web Engineer About us: Since our September 2013 launch, we’ve attracted thousands of developer users who immediately recognized the need for a service like Layer. And we&#x27;ve hired a stellar team. Individually we&#x27;ve built Google Voice, invented the ubiquitous communications protocol, XMPP, and architected and deployed the OpenDNS network. Collectively we&#x27;re the best team in 					63	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its remote work option, entry-level experience requirements, and focus on iOS development, but lacks clear information on salary and product funding.	f			2026-05-08 17:05:50.922527+00
17	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=19057911	430615152fe2d31c001c17395a3cf2c9	Personal	Software Developer Apprentice	New York, NY	Yes	Unknown		swift	Personal | Software Developer Apprentice | New York, NY | REMOTE &#x2F; FULL TIME &#x2F; INTERNS | https:&#x2F;&#x2F;airtable.com&#x2F;shr7Gxoh0jDu3Dwr8 I&#x27;m hiring a Software Developer Apprentice, full-time and paid. There will be an emphasis on learning and quality, not speed of development. You&#x27;ll work on: frontend and backend web applications, mobile applications, desktop applications, and APIs. ============================= Software Developer Apprentice This is an excellent opportunity for an aspiring software developer who is eager to learn by doing. Details: The position is full-time and paid. Day to day work will be remote, but candidates may prefer to relocate to New York City temporarily for in person mentorship and learning opportunities. In this position you will be ta					63	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its remote work option, entry-level experience requirements, and focus on learning and quality, but lacks clear iOS product confirmation and salary information.	f			2026-05-08 17:05:58.481342+00
83	2026-04-28 11:30:00.522579+00	Arc.dev	https://arc.dev/remote-jobs/j/outsourced-lead-product-designer-oh3a33vvmv	a475d5269ae743e47c68087b730979b8		Lead Product Designer	Remote	Yes	Unknown		ios, swift	Outsourced Lead Product Designer Full-time Lead iOS Team collaboration Ux writing Growth Product design Android Testing Research Web Development Mobile UI Support Design Systems User Research Usability testing Communications Storytelling UX design Mobile App Development UX/UI Design Accessibility Mentoring Visual design Interaction Design Advance prototyping Design Principles Remote - Philippines 3 days ago					43	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 0}	This internship opportunity is a good fit due to its remote work option and iOS relevance, but lacks clear experience requirements and salary information.	f			2026-05-08 16:57:10.188086+00
70	2026-04-27 06:24:59.943714+00	Arc.dev	https://arc.dev/remote-jobs/j/crossing-hurdles-web-designer-65-hr-remote-okt6ydt1o4	2b390d4b8c507b0823434a9071d0080a		Web Designer | $65/hr Remote	Remote	Yes	Unknown		ios, swift, salary:$65/hr	Crossing Hurdles Web Designer | $65/hr Remote Freelance Swift Web Development React Vue.js Bootstrap Web Design SQL Java jQuery Amazon EC2 Scala Algorithm Cloud UX design Apache Spark E-commerce Research User Research Interface Design Data Apache Kafka System design Network Windows Application AI Communications Remote - Canada a day ago					65	{"visa": 0, "remote": 20, "salary": 10, "ios_relevance": 15, "product_quality": 0, "experience_match": 20}	This internship opportunity is a good match due to its remote work option, clear experience requirements, and specified compensation, but lacks clear iOS product confirmation and funding information.	f			2026-05-08 16:59:19.469366+00
50	2026-04-23 11:44:52.136775+00	HackerNews	https://news.ycombinator.com/item?id=17216709	5a80fbbb9a77d2f07968fa751dd4a560	Handsome	iOS, Android and Web Frontend/Full stack Engineers	Austin, TX	Unknown	Yes	entry-level	combine	Handsome | iOS, Android and Web Frontend&#x2F;Full stack Engineers | Austin, TX | Onsite | Full-time Handsome is holistic experience design and technology agency. We combine our human-centered design approach with technical skillset to architect and build solutions that helps transform our clients&#x27; businesses. We have worked with FedEx, Home Depot, Facebook, Nickelodeon, Keller Williams, Indeed, Silvercar, WP Engine and more. We&#x27;re growing our team and are looking for strong iOS, Android and Web Frontend (or Full stack) developers. The positions are not suitable for entry-level or junior developers. Considering relocations but can&#x27;t sponsor visas at this time. https:&#x2F;&#x2F;www.handsome.is&#x2F;careers&#x2F;ios-software-engineer https:&#x2F;&#x2F;www.handsome.is&#x2F;car					48	{"visa": 5, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its entry-level experience requirement, visa sponsorship, and iOS relevance, but lacks remote work and salary information.	f			2026-05-08 17:06:30.788052+00
115	2026-05-03 16:52:32.734324+00	Google Jobs	https://job-boards.greenhouse.io/eulerity/jobs/4649821006	6b62d72df0565156c77ebebbd2e7c2eb	Eulerity	Jobs at Eulerity - Greenhouse		Unknown	Unknown			Mobile iOS Developer. Pune, Maharashtra, India · Mobile iOS Developer Intern. New York, New York. Finance. Job. Director, Finance. New York, New York. Marketing ...					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity has a good match for the candidate's experience, but lacks clear information about remote work, salary, and iOS product confirmation.	f			2026-05-08 16:52:23.53265+00
116	2026-05-03 16:52:32.734324+00	Google Jobs	https://jobs.ashbyhq.com/acorns/eafd7d09-b689-472d-80d1-65fbfa0e00c7	15f0554ae0cacc55bd7ccfee46c8abb8	Acorns - Jobs	Software Engineering Intern		Unknown	Unknown		swift	... internship (full-time availability for 10-weeks starting in June 2026) - Command of one or more programming languages; Java, Scala, Ruby, Swift, Kotlin ...					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, remote work uncertainty, and entry-level experience requirements, but lacks clear information on salary, product quality, and visa sponsorship.	f			2026-05-08 16:52:31.052636+00
119	2026-05-03 16:52:32.734324+00	Arc.dev	https://arc.dev/remote-jobs/j/squint-metrics-sr-ui-ux-designer-ombz0nm3n5	21002f948e3f901147fc0b030399e466	Squint Metrics	Sr. UI/UX Designer	Remote	Yes	Unknown		ios, swift	Squint Metrics Sr. UI/UX Designer Full-time Senior iOS Figma Wireframing/prototyping Ux writing Research Web Development Responsive Design Product design Material Design Testing Layout Design Responsive Layout Project documentation User flows Agile Scrum Version control UX design User Research Usability testing Design Systems Compliance Team collaboration UI design Advance prototyping Accessibility Component libraries Auto Layout Component Multi platform Remote - India New					43	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 0}	This internship opportunity is a good fit due to its remote work option and iOS relevance, but lacks clear experience requirements and salary information.	f			2026-05-08 16:52:38.561357+00
121	2026-05-03 16:52:32.734324+00	Arc.dev	https://arc.dev/remote-jobs/j/storyteller-software-engineer-web-sdk-nlqombsfyw	0f9806229116399c097bd0daf94b8043	Storyteller	Software Engineer (Web SDK)	Remote	Yes	Unknown		ios, swift	Storyteller Software Engineer (Web SDK) Full-time iOS AI Testing Web Development SaaS Software Development TypeScript JavaScript Android React Node.js Support Project management Continuous Integration Scripting language Content management Project documentation Editing & Proofreading NoSQL Data analytics Communications Team collaboration API HTTP SQL SDK Performance Optimization Ad Support Testing techniques Remote - South Africa New					55	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 0, "experience_match": 20}	This internship opportunity is a good match due to its remote work option, entry-level experience requirements, and iOS relevance, but lacks clear information on product quality and salary.	f			2026-05-08 16:52:53.758599+00
117	2026-05-03 16:52:32.734324+00	Google Jobs	https://boards.greenhouse.io/airbnb/jobs/7773838	bedd8391575878feb79e8abbd7b3ebf0	Airbnb	Software Engineer, Airbnb - New Grad - Careers at Airbnb		Unknown	Unknown		swift, objective-c	Proficiency in one or more of: Java, Scala, Ruby, Ruby on Rails, C++, SQL, HTML/CSS, JavaScript, Objective-C, Swift (iOS), or Kotlin (Android) ... Internship ...					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity at Airbnb is a good match due to its relevance to iOS development and the fact that it's an internship, but lacks clear information on remote work, salary, and visa sponsorship.	f			2026-05-08 16:53:01.27704+00
114	2026-05-03 16:52:32.734324+00	Google Jobs	http://job-boards.greenhouse.io/eulerity/jobs/4671025006	af6b40c1f5e1b1c2c7baac89db4eba72	Eulerity	Mobile iOS Developer Intern		Unknown	Unknown			You'll own real work that ships to real users. Take an active role in developing, testing, and maintaining our iOS app using AI-first development practices — ...					43	{"visa": 0, "remote": 0, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 20}	This internship opportunity is a good match due to its relevance to iOS development, remote work uncertainty, and entry-level experience requirements, but lacks clear information on salary, product quality, and visa sponsorship.	f			2026-05-08 16:53:16.627204+00
124	2026-05-05 10:39:29.242597+00	Arc.dev	https://arc.dev/remote-jobs/j/defense-unicorns-product-designer-omkow6d5my	8113b56ec129ded2cd54230b4d978ad2	DefenseUnicorns	Product Designer	Remote	Yes	Unknown		ios, swift	DefenseUnicorns Product Designer Full-time iOS Software Development Security software Kubernetes Responsive Design Ux writing Android Testing System security Operations Automation Infrastructure Research CSS3 Product design Wireframing/prototyping Cloud Design Architecture Communications Material Design Figma Visual design Amazon Mobile App Development Personas User personas Web Development Azure Containers Project management System design UX analysis Interaction Design Animation Design Systems User journey mapping User flows User Research Innovation Terraform Support Data AI Infrastructure as					43	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 8, "experience_match": 0}	This internship opportunity is a good fit due to its remote work option and iOS relevance, but lacks clear experience requirements and salary information.	f			2026-05-08 16:51:45.48834+00
118	2026-05-03 16:52:32.734324+00	Arc.dev	https://arc.dev/remote-jobs/j/teksystems-product-designer-design-systems-nd1mzswggr	f70ae753c165509738c78893e2d381e3	TEKsystems	Product Designer (Design Systems)	Remote	Yes	Unknown		ios, swift	TEKsystems Product Designer (Design Systems) Full-time iOS Figma Wireframing/prototyping Android Design Systems Support Web Development Product design Project management Project documentation Cloud Scalability Mobile UI Mockups Marketing strategies Content marketing Content management Adobe Photoshop Adobe InDesign Operations Adobe creative cloud Illustration AI Component libraries Presentation design Advance prototyping Prototype.js Remote - North America New					35	{"visa": 0, "remote": 20, "salary": 0, "ios_relevance": 15, "product_quality": 0, "experience_match": 0}	This internship opportunity is a good fit due to its remote work option and iOS relevance, but lacks clear experience requirements and salary information.	f			2026-05-08 16:52:15.830703+00
\.


--
-- Data for Name: processed_data; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.processed_data ("workflowId", context, "createdAt", "updatedAt", value) FROM stdin;
\.


--
-- Data for Name: project; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.project (id, name, type, "createdAt", "updatedAt", icon, description, "creatorId") FROM stdin;
DGOtkH1dYuWz6cM8	Sahan Maiti <sahanmaiti2005@gmail.com>	personal	2026-04-21 15:15:07.977+00	2026-04-24 10:31:25.795+00	\N	\N	53d71736-ba1a-44ab-ba08-8a9fbe5cee25
\.


--
-- Data for Name: project_relation; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.project_relation ("projectId", "userId", role, "createdAt", "updatedAt") FROM stdin;
DGOtkH1dYuWz6cM8	53d71736-ba1a-44ab-ba08-8a9fbe5cee25	project:personalOwner	2026-04-21 15:15:07.977+00	2026-04-21 15:15:07.977+00
\.


--
-- Data for Name: project_secrets_provider_access; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.project_secrets_provider_access ("secretsProviderConnectionId", "projectId", "createdAt", "updatedAt", role) FROM stdin;
\.


--
-- Data for Name: role; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.role (slug, "displayName", description, "roleType", "systemRole", "createdAt", "updatedAt") FROM stdin;
global:chatUser	Chat User	Chat User	global	t	2026-04-21 15:15:08.522+00	2026-04-21 15:15:08.522+00
global:owner	Owner	Owner	global	t	2026-04-21 15:15:08.23+00	2026-04-21 15:15:08.537+00
global:admin	Admin	Admin	global	t	2026-04-21 15:15:08.23+00	2026-04-21 15:15:08.537+00
global:member	Member	Member	global	t	2026-04-21 15:15:08.23+00	2026-04-21 15:15:08.537+00
project:admin	Project Admin	Full control of settings, members, workflows, credentials and executions	project	t	2026-04-21 15:15:08.23+00	2026-04-21 15:15:08.548+00
project:personalOwner	Project Owner	Project Owner	project	t	2026-04-21 15:15:08.23+00	2026-04-21 15:15:08.548+00
project:editor	Project Editor	Create, edit, and delete workflows, credentials, and executions	project	t	2026-04-21 15:15:08.23+00	2026-04-21 15:15:08.548+00
project:viewer	Project Viewer	Read-only access to workflows, credentials, and executions	project	t	2026-04-21 15:15:08.23+00	2026-04-21 15:15:08.548+00
project:chatUser	Project Chat User	Chat-only access to chatting with workflows that have n8n Chat enabled	project	t	2026-04-21 15:15:08.23+00	2026-04-21 15:15:08.548+00
credential:owner	Credential Owner	Credential Owner	credential	t	2026-04-21 15:15:08.522+00	2026-04-21 15:15:08.522+00
credential:user	Credential User	Credential User	credential	t	2026-04-21 15:15:08.522+00	2026-04-21 15:15:08.522+00
workflow:owner	Workflow Owner	Workflow Owner	workflow	t	2026-04-21 15:15:08.522+00	2026-04-21 15:15:08.522+00
workflow:editor	Workflow Editor	Workflow Editor	workflow	t	2026-04-21 15:15:08.522+00	2026-04-21 15:15:08.522+00
secretsProviderConnection:owner	Secrets Provider Connection Owner	Full control of secrets provider connection settings and secrets	secretsProviderConnection	t	2026-04-21 15:15:08.522+00	2026-04-21 15:15:08.522+00
secretsProviderConnection:user	Secrets Provider Connection User	Read-only access to use secrets from the connection	secretsProviderConnection	t	2026-04-21 15:15:08.522+00	2026-04-21 15:15:08.522+00
\.


--
-- Data for Name: role_mapping_rule; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.role_mapping_rule (id, expression, role, type, "order", "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: role_mapping_rule_project; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.role_mapping_rule_project ("roleMappingRuleId", "projectId") FROM stdin;
\.


--
-- Data for Name: role_scope; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.role_scope ("roleSlug", "scopeSlug") FROM stdin;
global:owner	workflow:unpublish
global:owner	workflow:unshare
global:owner	credential:unshare
global:owner	aiAssistant:manage
global:owner	annotationTag:create
global:owner	annotationTag:read
global:owner	annotationTag:update
global:owner	annotationTag:delete
global:owner	annotationTag:list
global:owner	auditLogs:manage
global:owner	banner:dismiss
global:owner	community:register
global:owner	communityPackage:install
global:owner	communityPackage:uninstall
global:owner	communityPackage:update
global:owner	communityPackage:list
global:owner	credential:share
global:owner	credential:shareGlobally
global:owner	credential:move
global:owner	credential:create
global:owner	credential:read
global:owner	credential:update
global:owner	credential:delete
global:owner	credential:list
global:owner	externalSecretsProvider:sync
global:owner	externalSecretsProvider:create
global:owner	externalSecretsProvider:read
global:owner	externalSecretsProvider:update
global:owner	externalSecretsProvider:delete
global:owner	externalSecretsProvider:list
global:owner	externalSecret:list
global:owner	eventBusDestination:test
global:owner	eventBusDestination:create
global:owner	eventBusDestination:read
global:owner	eventBusDestination:update
global:owner	eventBusDestination:delete
global:owner	eventBusDestination:list
global:owner	ldap:sync
global:owner	ldap:manage
global:owner	license:manage
global:owner	logStreaming:manage
global:owner	orchestration:read
global:owner	project:create
global:owner	project:read
global:owner	project:update
global:owner	project:delete
global:owner	project:list
global:owner	saml:manage
global:owner	securityAudit:generate
global:owner	securitySettings:manage
global:owner	sourceControl:pull
global:owner	sourceControl:push
global:owner	sourceControl:manage
global:owner	tag:create
global:owner	tag:read
global:owner	tag:update
global:owner	tag:delete
global:owner	tag:list
global:owner	user:resetPassword
global:owner	user:changeRole
global:owner	user:enforceMfa
global:owner	user:generateInviteLink
global:owner	user:create
global:owner	user:read
global:owner	user:update
global:owner	user:delete
global:owner	user:list
global:owner	variable:create
global:owner	variable:read
global:owner	variable:update
global:owner	variable:delete
global:owner	variable:list
global:owner	projectVariable:create
global:owner	projectVariable:read
global:owner	projectVariable:update
global:owner	projectVariable:delete
global:owner	projectVariable:list
global:owner	workersView:manage
global:owner	workflow:share
global:owner	workflow:execute
global:owner	workflow:execute-chat
global:owner	workflow:move
global:owner	workflow:updateRedactionSetting
global:owner	workflow:create
global:owner	workflow:read
global:owner	workflow:update
global:owner	workflow:delete
global:owner	workflow:list
global:owner	folder:create
global:owner	folder:read
global:owner	folder:update
global:owner	folder:delete
global:owner	folder:list
global:owner	folder:move
global:owner	insights:list
global:owner	insights:read
global:owner	oidc:manage
global:owner	provisioning:manage
global:owner	dataTable:create
global:owner	dataTable:read
global:owner	dataTable:update
global:owner	dataTable:delete
global:owner	dataTable:list
global:owner	dataTable:readRow
global:owner	dataTable:writeRow
global:owner	dataTable:listProject
global:owner	execution:reveal
global:owner	role:manage
global:owner	mcp:manage
global:owner	mcp:oauth
global:owner	mcpApiKey:create
global:owner	mcpApiKey:rotate
global:owner	chatHub:manage
global:owner	chatHub:message
global:owner	chatHubAgent:create
global:owner	chatHubAgent:read
global:owner	chatHubAgent:update
global:owner	chatHubAgent:delete
global:owner	chatHubAgent:list
global:owner	breakingChanges:list
global:owner	apiKey:manage
global:owner	credentialResolver:create
global:owner	credentialResolver:read
global:owner	credentialResolver:update
global:owner	credentialResolver:delete
global:owner	credentialResolver:list
global:owner	instanceAi:message
global:owner	instanceAi:manage
global:owner	instanceAi:gateway
global:owner	roleMappingRule:create
global:owner	roleMappingRule:read
global:owner	roleMappingRule:update
global:owner	roleMappingRule:delete
global:owner	roleMappingRule:list
global:owner	workflow:publish
global:admin	workflow:unpublish
global:admin	workflow:unshare
global:admin	credential:unshare
global:admin	aiAssistant:manage
global:admin	annotationTag:create
global:admin	annotationTag:read
global:admin	annotationTag:update
global:admin	annotationTag:delete
global:admin	annotationTag:list
global:admin	auditLogs:manage
global:admin	banner:dismiss
global:admin	community:register
global:admin	communityPackage:install
global:admin	communityPackage:uninstall
global:admin	communityPackage:update
global:admin	communityPackage:list
global:admin	credential:share
global:admin	credential:shareGlobally
global:admin	credential:move
global:admin	credential:create
global:admin	credential:read
global:admin	credential:update
global:admin	credential:delete
global:admin	credential:list
global:admin	externalSecretsProvider:sync
global:admin	externalSecretsProvider:create
global:admin	externalSecretsProvider:read
global:admin	externalSecretsProvider:update
global:admin	externalSecretsProvider:delete
global:admin	externalSecretsProvider:list
global:admin	externalSecret:list
global:admin	eventBusDestination:test
global:admin	eventBusDestination:create
global:admin	eventBusDestination:read
global:admin	eventBusDestination:update
global:admin	eventBusDestination:delete
global:admin	eventBusDestination:list
global:admin	ldap:sync
global:admin	ldap:manage
global:admin	license:manage
global:admin	logStreaming:manage
global:admin	orchestration:read
global:admin	project:create
global:admin	project:read
global:admin	project:update
global:admin	project:delete
global:admin	project:list
global:admin	saml:manage
global:admin	securityAudit:generate
global:admin	securitySettings:manage
global:admin	sourceControl:pull
global:admin	sourceControl:push
global:admin	sourceControl:manage
global:admin	tag:create
global:admin	tag:read
global:admin	tag:update
global:admin	tag:delete
global:admin	tag:list
global:admin	user:resetPassword
global:admin	user:changeRole
global:admin	user:enforceMfa
global:admin	user:generateInviteLink
global:admin	user:create
global:admin	user:read
global:admin	user:update
global:admin	user:delete
global:admin	user:list
global:admin	variable:create
global:admin	variable:read
global:admin	variable:update
global:admin	variable:delete
global:admin	variable:list
global:admin	projectVariable:create
global:admin	projectVariable:read
global:admin	projectVariable:update
global:admin	projectVariable:delete
global:admin	projectVariable:list
global:admin	workersView:manage
global:admin	workflow:share
global:admin	workflow:execute
global:admin	workflow:execute-chat
global:admin	workflow:move
global:admin	workflow:updateRedactionSetting
global:admin	workflow:create
global:admin	workflow:read
global:admin	workflow:update
global:admin	workflow:delete
global:admin	workflow:list
global:admin	folder:create
global:admin	folder:read
global:admin	folder:update
global:admin	folder:delete
global:admin	folder:list
global:admin	folder:move
global:admin	insights:list
global:admin	insights:read
global:admin	oidc:manage
global:admin	provisioning:manage
global:admin	dataTable:create
global:admin	dataTable:read
global:admin	dataTable:update
global:admin	dataTable:delete
global:admin	dataTable:list
global:admin	dataTable:readRow
global:admin	dataTable:writeRow
global:admin	dataTable:listProject
global:admin	execution:reveal
global:admin	role:manage
global:admin	mcp:manage
global:admin	mcp:oauth
global:admin	mcpApiKey:create
global:admin	mcpApiKey:rotate
global:admin	chatHub:manage
global:admin	chatHub:message
global:admin	chatHubAgent:create
global:admin	chatHubAgent:read
global:admin	chatHubAgent:update
global:admin	chatHubAgent:delete
global:admin	chatHubAgent:list
global:admin	breakingChanges:list
global:admin	apiKey:manage
global:admin	credentialResolver:create
global:admin	credentialResolver:read
global:admin	credentialResolver:update
global:admin	credentialResolver:delete
global:admin	credentialResolver:list
global:admin	instanceAi:message
global:admin	instanceAi:manage
global:admin	instanceAi:gateway
global:admin	roleMappingRule:create
global:admin	roleMappingRule:read
global:admin	roleMappingRule:update
global:admin	roleMappingRule:delete
global:admin	roleMappingRule:list
global:admin	workflow:publish
global:member	annotationTag:create
global:member	annotationTag:read
global:member	annotationTag:update
global:member	annotationTag:delete
global:member	annotationTag:list
global:member	eventBusDestination:test
global:member	eventBusDestination:list
global:member	tag:create
global:member	tag:read
global:member	tag:update
global:member	tag:list
global:member	user:list
global:member	variable:read
global:member	variable:list
global:member	insights:read
global:member	dataTable:list
global:member	mcp:oauth
global:member	mcpApiKey:create
global:member	mcpApiKey:rotate
global:member	chatHub:message
global:member	chatHubAgent:create
global:member	chatHubAgent:read
global:member	chatHubAgent:update
global:member	chatHubAgent:delete
global:member	chatHubAgent:list
global:member	apiKey:manage
global:member	credentialResolver:list
global:member	instanceAi:message
global:member	instanceAi:gateway
global:chatUser	chatHub:message
global:chatUser	chatHubAgent:create
global:chatUser	chatHubAgent:read
global:chatUser	chatHubAgent:update
global:chatUser	chatHubAgent:delete
global:chatUser	chatHubAgent:list
project:admin	workflow:unpublish
project:admin	credential:unshare
project:admin	credential:share
project:admin	credential:move
project:admin	credential:create
project:admin	credential:read
project:admin	credential:update
project:admin	credential:delete
project:admin	credential:list
project:admin	project:read
project:admin	project:update
project:admin	project:delete
project:admin	project:list
project:admin	sourceControl:push
project:admin	projectVariable:create
project:admin	projectVariable:read
project:admin	projectVariable:update
project:admin	projectVariable:delete
project:admin	projectVariable:list
project:admin	workflow:execute
project:admin	workflow:execute-chat
project:admin	workflow:move
project:admin	workflow:updateRedactionSetting
project:admin	workflow:create
project:admin	workflow:read
project:admin	workflow:update
project:admin	workflow:delete
project:admin	workflow:list
project:admin	folder:create
project:admin	folder:read
project:admin	folder:update
project:admin	folder:delete
project:admin	folder:list
project:admin	folder:move
project:admin	dataTable:create
project:admin	dataTable:read
project:admin	dataTable:update
project:admin	dataTable:delete
project:admin	dataTable:readRow
project:admin	dataTable:writeRow
project:admin	dataTable:listProject
project:admin	execution:reveal
project:admin	workflow:publish
project:personalOwner	workflow:unpublish
project:personalOwner	workflow:unshare
project:personalOwner	credential:unshare
project:personalOwner	credential:share
project:personalOwner	credential:move
project:personalOwner	credential:create
project:personalOwner	credential:read
project:personalOwner	credential:update
project:personalOwner	credential:delete
project:personalOwner	credential:list
project:personalOwner	project:read
project:personalOwner	project:list
project:personalOwner	workflow:share
project:personalOwner	workflow:execute
project:personalOwner	workflow:execute-chat
project:personalOwner	workflow:move
project:personalOwner	workflow:updateRedactionSetting
project:personalOwner	workflow:create
project:personalOwner	workflow:read
project:personalOwner	workflow:update
project:personalOwner	workflow:delete
project:personalOwner	workflow:list
project:personalOwner	folder:create
project:personalOwner	folder:read
project:personalOwner	folder:update
project:personalOwner	folder:delete
project:personalOwner	folder:list
project:personalOwner	folder:move
project:personalOwner	dataTable:create
project:personalOwner	dataTable:read
project:personalOwner	dataTable:update
project:personalOwner	dataTable:delete
project:personalOwner	dataTable:readRow
project:personalOwner	dataTable:writeRow
project:personalOwner	dataTable:listProject
project:personalOwner	execution:reveal
project:personalOwner	workflow:publish
project:editor	workflow:unpublish
project:editor	credential:create
project:editor	credential:read
project:editor	credential:update
project:editor	credential:delete
project:editor	credential:list
project:editor	project:read
project:editor	project:list
project:editor	projectVariable:create
project:editor	projectVariable:read
project:editor	projectVariable:update
project:editor	projectVariable:delete
project:editor	projectVariable:list
project:editor	workflow:execute
project:editor	workflow:execute-chat
project:editor	workflow:create
project:editor	workflow:read
project:editor	workflow:update
project:editor	workflow:delete
project:editor	workflow:list
project:editor	folder:create
project:editor	folder:read
project:editor	folder:update
project:editor	folder:delete
project:editor	folder:list
project:editor	dataTable:create
project:editor	dataTable:read
project:editor	dataTable:update
project:editor	dataTable:delete
project:editor	dataTable:readRow
project:editor	dataTable:writeRow
project:editor	dataTable:listProject
project:editor	workflow:publish
project:viewer	credential:read
project:viewer	credential:list
project:viewer	project:read
project:viewer	project:list
project:viewer	projectVariable:read
project:viewer	projectVariable:list
project:viewer	workflow:execute-chat
project:viewer	workflow:read
project:viewer	workflow:list
project:viewer	folder:read
project:viewer	folder:list
project:viewer	dataTable:read
project:viewer	dataTable:readRow
project:viewer	dataTable:listProject
project:chatUser	workflow:execute-chat
credential:owner	credential:unshare
credential:owner	credential:share
credential:owner	credential:move
credential:owner	credential:read
credential:owner	credential:update
credential:owner	credential:delete
credential:user	credential:read
workflow:owner	workflow:unpublish
workflow:owner	workflow:unshare
workflow:owner	workflow:share
workflow:owner	workflow:execute
workflow:owner	workflow:execute-chat
workflow:owner	workflow:move
workflow:owner	workflow:read
workflow:owner	workflow:update
workflow:owner	workflow:delete
workflow:owner	workflow:publish
workflow:editor	workflow:unpublish
workflow:editor	workflow:execute
workflow:editor	workflow:execute-chat
workflow:editor	workflow:read
workflow:editor	workflow:update
workflow:editor	workflow:publish
secretsProviderConnection:owner	externalSecretsProvider:sync
secretsProviderConnection:owner	externalSecretsProvider:read
secretsProviderConnection:owner	externalSecretsProvider:update
secretsProviderConnection:owner	externalSecretsProvider:delete
secretsProviderConnection:owner	externalSecretsProvider:list
secretsProviderConnection:owner	externalSecret:list
secretsProviderConnection:user	externalSecretsProvider:read
secretsProviderConnection:user	externalSecretsProvider:list
secretsProviderConnection:user	externalSecret:list
\.


--
-- Data for Name: scope; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.scope (slug, "displayName", description) FROM stdin;
workflow:unpublish	Unpublish Workflow	Allows unpublishing workflows.
workflow:unshare	Unshare Workflow	Allows removing workflow shares.
credential:unshare	Unshare Credential	Allows removing credential shares.
aiAssistant:manage	Manage AI Usage	Allows managing AI Usage settings.
aiAssistant:*	aiAssistant:*	\N
annotationTag:create	Create Annotation Tag	Allows creating new annotation tags.
annotationTag:read	annotationTag:read	\N
annotationTag:update	annotationTag:update	\N
annotationTag:delete	annotationTag:delete	\N
annotationTag:list	annotationTag:list	\N
annotationTag:*	annotationTag:*	\N
auditLogs:manage	auditLogs:manage	\N
auditLogs:*	auditLogs:*	\N
banner:dismiss	banner:dismiss	\N
banner:*	banner:*	\N
community:register	community:register	\N
community:*	community:*	\N
communityPackage:install	communityPackage:install	\N
communityPackage:uninstall	communityPackage:uninstall	\N
communityPackage:update	communityPackage:update	\N
communityPackage:list	communityPackage:list	\N
communityPackage:manage	communityPackage:manage	\N
communityPackage:*	communityPackage:*	\N
credential:share	credential:share	\N
credential:shareGlobally	credential:shareGlobally	\N
credential:move	credential:move	\N
credential:create	credential:create	\N
credential:read	credential:read	\N
credential:update	credential:update	\N
credential:delete	credential:delete	\N
credential:list	credential:list	\N
credential:*	credential:*	\N
externalSecretsProvider:sync	externalSecretsProvider:sync	\N
externalSecretsProvider:create	externalSecretsProvider:create	\N
externalSecretsProvider:read	externalSecretsProvider:read	\N
externalSecretsProvider:update	externalSecretsProvider:update	\N
externalSecretsProvider:delete	externalSecretsProvider:delete	\N
externalSecretsProvider:list	externalSecretsProvider:list	\N
externalSecretsProvider:*	externalSecretsProvider:*	\N
externalSecret:list	externalSecret:list	\N
externalSecret:*	externalSecret:*	\N
eventBusDestination:test	eventBusDestination:test	\N
eventBusDestination:create	eventBusDestination:create	\N
eventBusDestination:read	eventBusDestination:read	\N
eventBusDestination:update	eventBusDestination:update	\N
eventBusDestination:delete	eventBusDestination:delete	\N
eventBusDestination:list	eventBusDestination:list	\N
eventBusDestination:*	eventBusDestination:*	\N
ldap:sync	ldap:sync	\N
ldap:manage	ldap:manage	\N
ldap:*	ldap:*	\N
license:manage	license:manage	\N
license:*	license:*	\N
logStreaming:manage	logStreaming:manage	\N
logStreaming:*	logStreaming:*	\N
orchestration:read	orchestration:read	\N
orchestration:list	orchestration:list	\N
orchestration:*	orchestration:*	\N
project:create	project:create	\N
project:read	project:read	\N
project:update	project:update	\N
project:delete	project:delete	\N
project:list	project:list	\N
project:*	project:*	\N
saml:manage	saml:manage	\N
saml:*	saml:*	\N
securityAudit:generate	securityAudit:generate	\N
securityAudit:*	securityAudit:*	\N
securitySettings:manage	securitySettings:manage	\N
securitySettings:*	securitySettings:*	\N
sourceControl:pull	sourceControl:pull	\N
sourceControl:push	sourceControl:push	\N
sourceControl:manage	sourceControl:manage	\N
sourceControl:*	sourceControl:*	\N
tag:create	tag:create	\N
tag:read	tag:read	\N
tag:update	tag:update	\N
tag:delete	tag:delete	\N
tag:list	tag:list	\N
tag:*	tag:*	\N
user:resetPassword	user:resetPassword	\N
user:changeRole	user:changeRole	\N
user:enforceMfa	user:enforceMfa	\N
user:generateInviteLink	user:generateInviteLink	\N
user:create	user:create	\N
user:read	user:read	\N
user:update	user:update	\N
user:delete	user:delete	\N
user:list	user:list	\N
user:*	user:*	\N
variable:create	variable:create	\N
variable:read	variable:read	\N
variable:update	variable:update	\N
variable:delete	variable:delete	\N
variable:list	variable:list	\N
variable:*	variable:*	\N
projectVariable:create	projectVariable:create	\N
projectVariable:read	projectVariable:read	\N
projectVariable:update	projectVariable:update	\N
projectVariable:delete	projectVariable:delete	\N
projectVariable:list	projectVariable:list	\N
projectVariable:*	projectVariable:*	\N
workersView:manage	workersView:manage	\N
workersView:*	workersView:*	\N
workflow:share	workflow:share	\N
workflow:execute	workflow:execute	\N
workflow:execute-chat	workflow:execute-chat	\N
workflow:move	workflow:move	\N
workflow:activate	workflow:activate	\N
workflow:deactivate	workflow:deactivate	\N
workflow:updateRedactionSetting	workflow:updateRedactionSetting	\N
workflow:create	workflow:create	\N
workflow:read	workflow:read	\N
workflow:update	workflow:update	\N
workflow:delete	workflow:delete	\N
workflow:list	workflow:list	\N
workflow:*	workflow:*	\N
folder:create	folder:create	\N
folder:read	folder:read	\N
folder:update	folder:update	\N
folder:delete	folder:delete	\N
folder:list	folder:list	\N
folder:move	folder:move	\N
folder:*	folder:*	\N
insights:list	insights:list	\N
insights:read	Read Insights	Allows reading insights data.
insights:*	insights:*	\N
oidc:manage	oidc:manage	\N
oidc:*	oidc:*	\N
provisioning:manage	provisioning:manage	\N
provisioning:*	provisioning:*	\N
dataTable:create	dataTable:create	\N
dataTable:read	dataTable:read	\N
dataTable:update	dataTable:update	\N
dataTable:delete	dataTable:delete	\N
dataTable:list	dataTable:list	\N
dataTable:readRow	dataTable:readRow	\N
dataTable:writeRow	dataTable:writeRow	\N
dataTable:listProject	dataTable:listProject	\N
dataTable:*	dataTable:*	\N
execution:delete	execution:delete	\N
execution:read	execution:read	\N
execution:retry	execution:retry	\N
execution:list	execution:list	\N
execution:get	execution:get	\N
execution:reveal	execution:reveal	\N
execution:*	execution:*	\N
workflowTags:update	workflowTags:update	\N
workflowTags:list	workflowTags:list	\N
workflowTags:*	workflowTags:*	\N
role:manage	role:manage	\N
role:*	role:*	\N
mcp:manage	mcp:manage	\N
mcp:oauth	mcp:oauth	\N
mcp:*	mcp:*	\N
mcpApiKey:create	mcpApiKey:create	\N
mcpApiKey:rotate	mcpApiKey:rotate	\N
mcpApiKey:*	mcpApiKey:*	\N
chatHub:manage	chatHub:manage	\N
chatHub:message	chatHub:message	\N
chatHub:*	chatHub:*	\N
chatHubAgent:create	chatHubAgent:create	\N
chatHubAgent:read	chatHubAgent:read	\N
chatHubAgent:update	chatHubAgent:update	\N
chatHubAgent:delete	chatHubAgent:delete	\N
chatHubAgent:list	chatHubAgent:list	\N
chatHubAgent:*	chatHubAgent:*	\N
breakingChanges:list	breakingChanges:list	\N
breakingChanges:*	breakingChanges:*	\N
apiKey:manage	apiKey:manage	\N
apiKey:*	apiKey:*	\N
credentialResolver:create	credentialResolver:create	\N
credentialResolver:read	credentialResolver:read	\N
credentialResolver:update	credentialResolver:update	\N
credentialResolver:delete	credentialResolver:delete	\N
credentialResolver:list	credentialResolver:list	\N
credentialResolver:*	credentialResolver:*	\N
instanceAi:message	instanceAi:message	\N
instanceAi:manage	instanceAi:manage	\N
instanceAi:gateway	instanceAi:gateway	\N
instanceAi:*	instanceAi:*	\N
roleMappingRule:create	roleMappingRule:create	\N
roleMappingRule:read	roleMappingRule:read	\N
roleMappingRule:update	roleMappingRule:update	\N
roleMappingRule:delete	roleMappingRule:delete	\N
roleMappingRule:list	roleMappingRule:list	\N
roleMappingRule:*	roleMappingRule:*	\N
*	*	\N
workflow:publish	Publish Workflow	Allows publishing workflows.
\.


--
-- Data for Name: scrape_runs; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.scrape_runs (id, started_at, finished_at, jobs_found, jobs_new, jobs_scored, errors, triggered_by) FROM stdin;
1	2026-04-23 11:44:40.839881+00	2026-04-23 11:51:11.519841+00	69	51	0		manual
2	2026-04-24 13:43:41.250435+00	2026-04-24 13:43:58.192087+00	66	1	0		manual
3	2026-04-24 14:18:23.356984+00	2026-04-24 14:18:35.098662+00	70	0	0		manual
4	2026-04-26 16:43:01.844435+00	2026-04-26 16:43:46.067032+00	86	9	0		manual
5	2026-04-26 17:18:33.784985+00	2026-04-26 17:18:34.594281+00	0	0	0	name 'JobicyScraper' is not defined	manual
6	2026-04-27 06:23:40.590987+00	2026-04-27 06:25:02.215942+00	83	10	0		manual
7	2026-04-28 11:05:26.304763+00	2026-04-28 11:07:30.59871+00	96	11	0		manual
8	2026-04-28 11:27:51.15538+00	2026-04-28 11:30:02.141177+00	97	1	0		manual
9	2026-04-28 11:33:47.871889+00	2026-04-28 11:35:52.653366+00	97	0	0		manual
10	2026-04-28 20:38:21.147482+00	2026-04-28 20:40:28.796465+00	103	17	0		manual
11	2026-04-28 21:21:10.89641+00	2026-04-28 21:23:17.135005+00	103	2	0		manual
12	2026-04-29 12:40:09.171215+00	2026-04-29 12:42:33.386496+00	101	1	0		manual
13	2026-04-30 10:14:42.988458+00	2026-04-30 10:16:34.020495+00	102	7	0		manual
14	2026-04-30 20:49:42.929753+00	2026-04-30 20:51:49.404069+00	103	2	0		manual
15	2026-05-03 16:51:28.622682+00	2026-05-03 16:52:35.589794+00	102	0	0		manual
16	2026-05-03 16:51:35.198597+00	2026-05-03 16:53:23.672607+00	102	10	0		manual
18	2026-05-05 10:39:06.407588+00	2026-05-05 10:39:57.822861+00	100	0	0		manual
19	2026-05-05 10:39:25.641455+00	2026-05-05 10:40:15.455812+00	99	0	0		manual
17	2026-05-05 10:38:24.048727+00	2026-05-05 10:40:21.259175+00	99	4	0		manual
20	2026-05-05 11:04:27.537784+00	2026-05-05 11:05:30.641264+00	99	0	0		manual
21	2026-05-06 15:41:02.12831+00	2026-05-06 15:42:59.531551+00	99	6	0		manual
22	2026-05-07 07:38:38.306851+00	2026-05-07 07:40:31.609935+00	98	1	0		manual
23	2026-05-07 09:43:53.565986+00	2026-05-07 09:44:54.320109+00	98	0	0		manual
24	2026-05-07 10:31:30.732849+00	2026-05-07 10:33:15.962793+00	100	1	0		manual
25	2026-05-07 10:49:31.984817+00	2026-05-07 10:50:33.328901+00	100	0	0		manual
26	2026-05-07 10:50:00.342311+00	2026-05-07 10:50:52.008009+00	100	0	0		manual
27	2026-05-08 15:38:24.027615+00	2026-05-08 15:40:24.086306+00	101	3	0		manual
28	2026-05-08 16:48:15.032499+00	2026-05-08 16:50:20.45192+00	99	0	0		manual
29	2026-05-08 20:35:10.700272+00	2026-05-08 20:36:08.180574+00	101	0	0		manual
30	2026-05-10 16:13:52.770078+00	2026-05-10 16:16:06.478771+00	100	11	0		manual
31	2026-05-11 06:21:13.93433+00	2026-05-11 06:23:36.204573+00	102	78	0		manual
32	2026-05-12 06:00:44.84951+00	2026-05-12 06:02:43.996032+00	98	75	0		manual
33	2026-05-12 07:09:13.855483+00	2026-05-12 07:11:11.319199+00	97	74	0		manual
\.


--
-- Data for Name: secrets_provider_connection; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.secrets_provider_connection (id, "providerKey", type, "encryptedSettings", "isEnabled", "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: settings; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.settings (key, value, "loadOnStartup") FROM stdin;
ui.banners.dismissed	["V1"]	t
features.ldap	{"loginEnabled":false,"loginLabel":"","connectionUrl":"","allowUnauthorizedCerts":false,"connectionSecurity":"none","connectionPort":389,"baseDn":"","bindingAdminDn":"","bindingAdminPassword":"","firstNameAttribute":"","lastNameAttribute":"","emailAttribute":"","loginIdAttribute":"","ldapIdAttribute":"","userFilter":"","synchronizationEnabled":false,"synchronizationInterval":60,"searchPageSize":0,"searchTimeout":60,"enforceEmailUniqueness":true}	t
userManagement.isInstanceOwnerSetUp	true	t
license.cert	eyJsaWNlbnNlS2V5IjoiLS0tLS1CRUdJTiBMSUNFTlNFIEtFWS0tLS0tXG5rMDVlaGpsNGowbnZsQ3JCMHc5Ulg1cmpIa2xJZ2dtbVRRNUpIa0YxbmZaVng1S3BPOVRwTE0rdXVlLys5Tmw1XG5samZsNVJjV24yanA1NUpoTTR0S1NTRXpqMGJqMTZuVWIxUWhFdS9iZVRwbFJ4aEErL3FTak9TM2JidHQyVmR5XG51dEVEa1N3OWhFZHljb205L0RuQ3E3dDVjOW0zbi9CNm1VTHdWLzU2Y3lwOUx5Y3RMejEyMFFvaXp2K0dhVlhoXG5UTXBPUW9YY1VMaXBkUWt5L3d5VWJkbDZKYXFhdnkrRUVFTkg5eVlrVWU0Q0JxWEFmQ1NCNjJ1SlNmcXZPdUtjXG44em1TSUdEUkwyL3g3Zk9ROWs1RmpKY2Y3VVZzVWoyeTZvcjJubFhBMkhacXZqRzZyZFdJZ2NpUnJpbnN3Vm0xXG5NdUgxWmk5UmUxQXA5SVpZM2tRQzNRPT18fFUyRnNkR1ZrWDErTktkL1cvYXdlZXBIb01rcUpDTUo0d0tuTHVqXG5LYmtlbUtaZWhsVXE1bnFKemMzZFRsWjVJdTczZjR6Z0RlVXRzdWNsZk4rK3NaUWxuTkk1d2YrTEFpN3lXN0hOXG5DZEg0bHFTRU1wR0FETEF4V2Q5Q2lrTlJJZml1alFTdm1PdUtKOVJ6MU5wemM0VEF5eUJvVGs4ajJiNldndG9nXG42T3hDYmhXcjE3TDdyeWN6QktHREZ4VHp1SWREb0IrY2FaR1BxYVpOaCtDQkR1RjYwZ25EZWtZVVJTOVhtUlNlXG51V09iRk1vZjZtQUVEaGZTSkR6MUtyQjZOV3d3R1R1dzJ1b2xieFB5TERlUmVQU0dKVnBIeHJDdnllak5vQndoXG5GZjlDcEdDQmY0M0I1VGtRYlFuR01FWlRnUjFlbDFpSmlFejRTZmhuT2pTRUR4akhseDVpeEpmVmhIMWhJY3I2XG5MYnlHMzBadEwrbEd2dnhsY3p2VnJXekwzTDBTRE9HczBQUWtPc0dQbVdZU0ZHWWpHRnkzQ2V0RHBpNE9Lbm1SXG50RUlrUzIzYmNxZHN2cHV0QUVib3RwemtrOFlzREM1YnlyNU4zejRUYVBwNlM5R2J5MUxWSTNWOHZsWmFWSnNSXG55d2o2UmRSSnlYUGJDaUFybk40VC9EV0d0aEdzYTROaXcyL1hTTVhpaVhjQ3dTOWVZT2NqMmNFM2RYcndaS09XXG5rQnB3NWF4L05DWndVcHBqV3J5elJiRURFaHZUV0lINWhKQXI0a0RRTU5lWkpNSk8wVW1WaTZSSTJGQkhxNmVHXG5YMmE4SEZDaVpKZWlIQTFLMmYzT3JINDRJNDZ3ZUdiVjNSOFBxR29BYUcyVmVHR1NmM3J2MVJpNjNoWmNzVnBSXG5qVkRSeUNQRm9wUEdsT3VmWVdVd1lLNnB1UzE3TGc3WHNZUVlWdkNUREt1VUwrRlVSQ0ZCT2dVb0pNekdBOXNNXG5xbFR3RFdzbFdiMGx5UmFtL1pHZzl5WDlkN1ZNZVMrNzRYQU1LV3FLajFZdXptYmsrMmlzOC9DRkhsVGR5L3V0XG5GRGcybVN6Z1g1UUhkK2dIZ0NiQ3k2cUFpaFBsTUliSGtYTUIzRnFUbzFGYWNvVkpYSW42MHA4VHo2THQvSVpSXG5UdE5vWm1HMTZzT0VnamhJZnpSU24xTE8vRFpYYmQ3NElsUWJnUENyTitSblk4dTMvNDZZc2ltRG1mNWw2L05aXG5XTmdETmpIbEs5eFJDOWxkMU1VODZjTExtYVVNYU1sa2JPelg4M2c4SFhRRUdHd1FZWmJrT2pWUUFQbVNqeHU3XG5ZTzh1UlFsWWJCY3I1T1BHZjBJZWJ3Snh3RHpONEJjMzVaMDJ6STdEbEMvTUc4ZERqeno1WTd5aktXZlFIT3U2XG5kS2RkejNIN2kzRU1oRG1aMVZNRXQ3MFgwalN6dEY5NVBFRGtnUDBobE8yQkc4T2Y4NCt4NC9WcEpvZWNQT0wwXG44Ulhjd3UyQkNROTlib0J5alMybUxlU2dNWSt6TSt6VmVLbnczWkZwRkhsbkRHekRkZDc1QndiR1JNVnhOeWlMXG54WWtObjNkZ1pLSmtSckxDeWd3dDNjSWh2M3RoeURYc3FDSFJmTGtBbFo0KzFjMitsVThWTUhjZVVTSlRVdnUrXG40Tmx5RUlTa29aTjkvVGZ0VHpQNmRjUE80TDlBQysyL0xoUnFMc3dtTE9BVnJ0RGFFRTV0V2xaR3RLckFiamRIXG5mSmg1ZHhWMHFKUzJwV3hJRWpQbFFoMTYwQ1Y4MTJFY0h6dUdyQUt1SXBIaE5EemJHbTF5ZGRiN3R2MHJDcDlHXG5mQkQwRTd4Zkl3M0M5UmlaaFdUVDM2K2ZKM1hWeTRXRmZWbFR0Vldkd1RsNTZVVDVZNjByL2s3M3FwTUJEYWRxXG5kdmthc3hSZFNpWEc4b3BkUnpzQ0lVU2pPSHJrNVZRMk1kN1JXRlI2Sm9wbjNpSS9qSEdwRVZGa0FRaVFiWVBWXG4wTUJQKzNuaG9KemZhWWZDN0Z5bzkvM3ovR1VLZFJhOG1ZMFVzZllNcHB2NjdnMlZ3eEJMbGxCbklkaUVkalFoXG5HQWgxaWQ5U0xjWjFmcTdpMlFkQU4zVklJcnRsSmRHajNuK3RTdmNZaUpsRFZJb1A3bEt3TE5mckRZUmRaZzA3XG5QdnFDWjRweGFjWThid2FsOHl5QUk3YmxHOGlEQU5KSGhTdTlXcU4rSi9RaXJCWW1kQTZqSlZxNXI3bjdLblQzXG5TYXFiSTZ2MFdST0dQODkzeVZTWSs2bVdFNVFNMWYvWml0bHptb2w1eHJlNCt6TUt5RU55dFJVcU93TW9Nc0QvXG56VjdlMElicmpYVEZtQTBTQmVOMHNSb09TWjZ2VTlxRzYwVEloaWlMbGdEQmhyQ3dkandmVTd3UGU2TUgrU0pvXG5WWkl3WlY2My9pZStNYkJpQS9JWGRONVhhYThvOFlPd1BVUGJVMGxSVDNXYlNscDdUajJkQjRrak5JY1VVSmZ4XG5HM3BLbzZRbGRoRENrNHpqQjRxMFBjeGxZY1dLdUJ2Smhud0UrTmlVdFZFU1I3V0U0bklhNGFabWRMaVlZR2taXG5VZUVRNHYxQkxFb3pOL3pQVE8yNjVQSFNxdk9ySldBb2JFVjBqWitHZDcxOVNpck9Xc3RoNkdzOVlDdzVIRUhKXG5uVzlna29obEJNM3BKUEgyNEdzeU43cHlYenEwd3lyem80bVQ2bXByMUNtckRNRkxPSkFMeVh1Y2ZQUTNYd2h3XG5YMHowVVNpeG51R01SeENMeW85MnhPem9HWkR6WS9xYWVjOVptNlZtSmVOTkNUK3Ryb0tMQzZpS3ZSVEFnWVMrXG5YQzJRajRIdUxDbzR6a0h4ejNZWnhEOFI4TlJUTjRLWTAvTXVHekVxd3JxNiswSWtYamdHRlIvNnpqMitvRWh2XG5WZkMwZ2lWMXJ5aVhYVDlnNVdLSEJJeUNkeFZFVG9qWFpMbUtMc0NCSFM0MWhnUC9SeEQ3VU1wZmNKQ04xSjk1XG5HaGQ1YmpRMUF0ZzBoaEdjTGh2d2hEVGpyanFXeHVHN2xvNHlTemlKblFybXl5OGc9PXx8aG5lWEd1MnhqMnM4XG5KRDJ6TFlySDFtcEJvNVkwZU1scUZJZDB2R2w4bXU2K245U2c3enZycjA3a0FaR3gyMnB5UTROeGtObkgrSjhlXG5FdndhZUtqNzJXT0JzUkEyRWtqakZpSEc5d1Z6d1dUckJWdkw5aGgyUW5DOWtzaDY1YnpjVkdyOXVZTDZ5aXhDXG5mZXZHN25ROXNZeW16a1NQU1MwdSsyZG9oTkhMRkpOZkxzNVF2NFcyM014aXdjbXNpcEh6U1YwWHJNUEkvVjFVXG5jeTBoWkFidWw2U0tBaEdMQi8rRk1ObUVIN1FVMUVYVXhBYlcwYjYrWm9hVnd6M21KYWpTMHdrRWI4NTY2NENyXG5IKzhLTlJmRnJ4YksyM0o4L3RRa2hVOW5TWWo0a2xhSUlFdENpckd3YzNTaVQ4d0svbTYybDBIbmxDbjExdk81XG5UNUduQmVFSi9nPT1cbi0tLS0tRU5EIExJQ0VOU0UgS0VZLS0tLS0iLCJ4NTA5IjoiLS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tXG5NSUlFRERDQ0FmUUNDUUNxZzJvRFQ4MHh3akFOQmdrcWhraUc5dzBCQVFVRkFEQklNUXN3Q1FZRFZRUUdFd0pFXG5SVEVQTUEwR0ExVUVDQXdHUW1WeWJHbHVNUTh3RFFZRFZRUUhEQVpDWlhKc2FXNHhGekFWQmdOVkJBTU1EbXhwXG5ZMlZ1YzJVdWJqaHVMbWx2TUI0WERUSXlNRFl5TkRBME1UQTBNRm9YRFRJek1EWXlOREEwTVRBME1Gb3dTREVMXG5NQWtHQTFVRUJoTUNSRVV4RHpBTkJnTlZCQWdNQmtKbGNteHBiakVQTUEwR0ExVUVCd3dHUW1WeWJHbHVNUmN3XG5GUVlEVlFRRERBNXNhV05sYm5ObExtNDRiaTVwYnpDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDXG5BUW9DZ2dFQkFNQk0wNVhCNDRnNXhmbUNMd2RwVVR3QVQ4K0NCa3lMS0ZzZXprRDVLLzZXaGFYL1hyc2QvUWQwXG4yMEo3d2w1V2RIVTRjVkJtRlJqVndWemtsQ0syeVlKaThtang4c1hzR3E5UTFsYlVlTUtmVjlkc2dmdWhubEFTXG50blFaZ2x1Z09uRjJGZ1JoWGIvakswdHhUb2FvK2JORTZyNGdJRXpwa3RITEJUWXZ2aXVKbXJlZjdXYlBSdDRJXG5uZDlEN2xoeWJlYnloVjdrdXpqUUEvcFBLSFRGczhNVEhaOGhZVXhSeXJwbTMrTVl6UUQrYmpBMlUxRkljdGFVXG53UVhZV2FON3QydVR3Q3Q5ekFLc21ZL1dlT2J2bDNUWk41T05MQXp5V0dDdWxtNWN3S1IzeGJsQlp6WG5CNmdzXG5Pbk4yT0FkU3RjelRWQ3ljbThwY0ZVcnl0S1NLa0dFQ0F3RUFBVEFOQmdrcWhraUc5dzBCQVFVRkFBT0NBZ0VBXG5sSjAxd2NuMXZqWFhDSHVvaTdSMERKMWxseDErZGFmcXlFcVBBMjdKdStMWG1WVkdYUW9yUzFiOHhqVXFVa2NaXG5UQndiV0ZPNXo1ZFptTnZuYnlqYXptKzZvT2cwUE1hWXhoNlRGd3NJMlBPYmM3YkZ2MmVheXdQdC8xQ3BuYzQwXG5xVU1oZnZSeC9HQ1pQQ1d6My8yUlBKV1g5alFEU0hYQ1hxOEJXK0kvM2N1TERaeVkzZkVZQkIwcDNEdlZtYWQ2XG42V0hRYVVyaU4wL0xxeVNPcC9MWmdsbC90MDI5Z1dWdDA1WmliR29LK2NWaFpFY3NMY1VJaHJqMnVGR0ZkM0ltXG5KTGcxSktKN2pLU0JVUU9kSU1EdnNGVUY3WWRNdk11ckNZQTJzT05OOENaK0k1eFFWMUtTOWV2R0hNNWZtd2dTXG5PUEZ2UHp0RENpMC8xdVc5dE9nSHBvcnVvZGFjdCtFWk5rQVRYQ3ZaaXUydy9xdEtSSkY0VTRJVEVtNWFXMGt3XG42enVDOHh5SWt0N3ZoZHM0OFV1UlNHSDlqSnJBZW1sRWl6dEdJTGhHRHF6UUdZYmxoVVFGR01iQmI3amhlTHlDXG5MSjFXT0c2MkYxc3B4Q0tCekVXNXg2cFIxelQxbWhFZ2Q0TWtMYTZ6UFRwYWNyZDk1QWd4YUdLRUxhMVJXU0ZwXG5NdmRoR2s0TnY3aG5iOHIrQnVNUkM2aWVkUE1DelhxL001MGNOOEFnOGJ3K0oxYUZvKzBFSzJoV0phN2tpRStzXG45R3ZGalNkekNGbFVQaEtra1Vaa1NvNWFPdGNRcTdKdTZrV0JoTG9GWUtncHJscDFRVkIwc0daQTZvNkR0cWphXG5HNy9SazZ2YmFZOHdzTllLMnpCWFRUOG5laDVab1JaL1BKTFV0RUV0YzdZPVxuLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLSJ9	f
\.


--
-- Data for Name: shared_credentials; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.shared_credentials ("credentialsId", "projectId", role, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: shared_workflow; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.shared_workflow ("workflowId", "projectId", role, "createdAt", "updatedAt") FROM stdin;
irl7JgZwJOTujHbm	DGOtkH1dYuWz6cM8	workflow:owner	2026-04-24 13:57:46.222+00	2026-04-24 13:57:46.222+00
AlrynH2aZBv1h5NT	DGOtkH1dYuWz6cM8	workflow:owner	2026-04-24 14:28:48.417+00	2026-04-24 14:28:48.417+00
wg2lnJe3gmOxJddG	DGOtkH1dYuWz6cM8	workflow:owner	2026-04-28 11:34:29.429+00	2026-04-28 11:34:29.429+00
CD2GddIS6pD1N23E	DGOtkH1dYuWz6cM8	workflow:owner	2026-05-07 07:00:22.772+00	2026-05-07 07:00:22.772+00
\.


--
-- Data for Name: tag_entity; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.tag_entity (name, "createdAt", "updatedAt", id) FROM stdin;
\.


--
-- Data for Name: test_case_execution; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.test_case_execution (id, "testRunId", "executionId", status, "runAt", "completedAt", "errorCode", "errorDetails", metrics, "createdAt", "updatedAt", inputs, outputs) FROM stdin;
\.


--
-- Data for Name: test_run; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.test_run (id, "workflowId", status, "errorCode", "errorDetails", "runAt", "completedAt", metrics, "createdAt", "updatedAt", "runningInstanceId", "cancelRequested") FROM stdin;
\.


--
-- Data for Name: token_exchange_jti; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.token_exchange_jti (jti, "expiresAt", "createdAt") FROM stdin;
\.


--
-- Data for Name: user; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public."user" (id, email, "firstName", "lastName", password, "personalizationAnswers", "createdAt", "updatedAt", settings, disabled, "mfaEnabled", "mfaSecret", "mfaRecoveryCodes", "lastActiveAt", "roleSlug") FROM stdin;
53d71736-ba1a-44ab-ba08-8a9fbe5cee25	sahanmaiti2005@gmail.com	Sahan	Maiti	$2a$10$GhRmV6aeZSJnrtOmy4bHzeVCSfgVgleUSqX9s.eWBKoyyVAxTol6e	{"version":"v4","personalization_survey_submitted_at":"2026-04-24T10:32:22.647Z","personalization_survey_n8n_version":"2.16.2","automationGoalDevops":[],"companySize":"personalUser","companyType":"saas","role":"engineering","reportedSource":"youtube"}	2026-04-21 15:15:07.755+00	2026-05-12 11:11:45.917+00	{"userActivated":true,"easyAIWorkflowOnboarded":true,"firstSuccessfulWorkflowId":"AlrynH2aZBv1h5NT","userActivatedAt":1777408700574,"npsSurvey":{"responded":true,"lastShownAt":1777967953800}}	f	f	\N	\N	2026-05-12	global:owner
\.


--
-- Data for Name: user_api_keys; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.user_api_keys (id, "userId", label, "apiKey", "createdAt", "updatedAt", scopes, audience) FROM stdin;
\.


--
-- Data for Name: variables; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.variables (key, type, value, id, "projectId") FROM stdin;
\.


--
-- Data for Name: webhook_entity; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.webhook_entity ("webhookPath", method, node, "webhookId", "pathLength", "workflowId") FROM stdin;
\.


--
-- Data for Name: workflow_builder_session; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.workflow_builder_session (id, "workflowId", "userId", messages, "previousSummary", "createdAt", "updatedAt", "activeVersionCardId", "resumeAfterRestoreMessageId") FROM stdin;
\.


--
-- Data for Name: workflow_dependency; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.workflow_dependency (id, "workflowId", "workflowVersionId", "dependencyType", "dependencyKey", "dependencyInfo", "indexVersionId", "createdAt", "publishedVersionId") FROM stdin;
202	irl7JgZwJOTujHbm	23	nodeType	n8n-nodes-base.scheduleTrigger	{"nodeId":"a8d8e941-839c-4994-8e5d-590a17b21236","nodeVersion":1.2}	1	2026-05-07 11:02:40.726+00	\N
203	irl7JgZwJOTujHbm	23	nodeType	n8n-nodes-base.code	{"nodeId":"6cbb17c4-be30-4171-b346-ab37c0b0fee5","nodeVersion":2}	1	2026-05-07 11:02:40.726+00	\N
204	irl7JgZwJOTujHbm	23	nodeType	n8n-nodes-base.code	{"nodeId":"443da55f-7aaf-4752-b084-2415fee40658","nodeVersion":2}	1	2026-05-07 11:02:40.726+00	\N
205	irl7JgZwJOTujHbm	23	nodeType	n8n-nodes-base.httpRequest	{"nodeId":"7567a15f-1fa3-443b-aa40-ead578f52fe0","nodeVersion":4.2}	1	2026-05-07 11:02:40.726+00	\N
206	irl7JgZwJOTujHbm	23	nodeType	n8n-nodes-base.executeCommand	{"nodeId":"02a864ff-c4ea-484f-a935-05dea56f2cfd","nodeVersion":1}	1	2026-05-07 11:02:40.726+00	\N
232	AlrynH2aZBv1h5NT	19	nodeType	n8n-nodes-base.scheduleTrigger	{"nodeId":"b38e6f47-0ed0-45d9-a630-e43103d9b9a4","nodeVersion":1.2}	1	2026-05-13 05:52:07.829+00	\N
233	AlrynH2aZBv1h5NT	19	nodeType	n8n-nodes-base.httpRequest	{"nodeId":"9616ca6d-5bb5-4253-a71f-8b0ce2579597","nodeVersion":4.2}	1	2026-05-13 05:52:07.829+00	\N
234	AlrynH2aZBv1h5NT	19	nodeType	n8n-nodes-base.code	{"nodeId":"e8edd62b-4643-469c-9e33-08d99f49cbd6","nodeVersion":2}	1	2026-05-13 05:52:07.829+00	\N
235	AlrynH2aZBv1h5NT	19	nodeType	n8n-nodes-base.code	{"nodeId":"c35065a3-6aa5-4045-be9b-09be07881794","nodeVersion":2}	1	2026-05-13 05:52:07.829+00	\N
236	AlrynH2aZBv1h5NT	19	nodeType	n8n-nodes-base.httpRequest	{"nodeId":"8e6ca49a-ea77-4b21-921b-c447b52a6954","nodeVersion":4.2}	1	2026-05-13 05:52:07.829+00	\N
120	wg2lnJe3gmOxJddG	1	nodeType	n8n-nodes-base.stickyNote	{"nodeId":"101bdee1-4de4-4b5e-9170-4d490d4e8128","nodeVersion":1}	1	2026-04-28 11:34:29.479+00	\N
121	wg2lnJe3gmOxJddG	1	nodeType	@blotato/n8n-nodes-blotato.blotato	{"nodeId":"db2db976-7988-4939-a931-b6b2b98570aa","nodeVersion":2}	1	2026-04-28 11:34:29.479+00	\N
122	wg2lnJe3gmOxJddG	1	nodeType	@blotato/n8n-nodes-blotato.blotato	{"nodeId":"6866a654-e6a7-4543-b98a-8288f9d04b47","nodeVersion":2}	1	2026-04-28 11:34:29.479+00	\N
123	wg2lnJe3gmOxJddG	1	nodeType	@blotato/n8n-nodes-blotato.blotato	{"nodeId":"a1b51932-2e2c-4e32-a37a-7ce94620cdd9","nodeVersion":2}	1	2026-04-28 11:34:29.479+00	\N
124	wg2lnJe3gmOxJddG	1	nodeType	n8n-nodes-base.merge	{"nodeId":"2c6cb6a6-e4b2-470d-8afb-b2c03b72e97b","nodeVersion":3.2}	1	2026-04-28 11:34:29.479+00	\N
125	wg2lnJe3gmOxJddG	1	nodeType	n8n-nodes-base.googleSheets	{"nodeId":"bee496d6-fc2d-4f1c-812f-9d6be08154a7","nodeVersion":4.5}	1	2026-04-28 11:34:29.479+00	\N
126	wg2lnJe3gmOxJddG	1	nodeType	@blotato/n8n-nodes-blotato.blotato	{"nodeId":"5f7344d8-a277-457b-a33f-c48e2ced1e49","nodeVersion":2}	1	2026-04-28 11:34:29.479+00	\N
127	wg2lnJe3gmOxJddG	1	nodeType	@blotato/n8n-nodes-blotato.blotato	{"nodeId":"31bc2347-2457-4fad-8436-09282df89609","nodeVersion":2}	1	2026-04-28 11:34:29.479+00	\N
128	wg2lnJe3gmOxJddG	1	nodeType	@blotato/n8n-nodes-blotato.blotato	{"nodeId":"06e29e46-c3ce-4c9e-825d-39df924a607d","nodeVersion":2}	1	2026-04-28 11:34:29.479+00	\N
129	wg2lnJe3gmOxJddG	1	nodeType	@blotato/n8n-nodes-blotato.blotato	{"nodeId":"3f7560c8-3e4a-4d62-bf62-e8d543df8026","nodeVersion":2}	1	2026-04-28 11:34:29.479+00	\N
130	wg2lnJe3gmOxJddG	1	nodeType	@blotato/n8n-nodes-blotato.blotato	{"nodeId":"3e4b6251-7c56-40ca-8fb6-4b77c910a2e6","nodeVersion":2}	1	2026-04-28 11:34:29.479+00	\N
131	wg2lnJe3gmOxJddG	1	nodeType	@blotato/n8n-nodes-blotato.blotato	{"nodeId":"61f5f513-b7ec-40ca-a4a1-1b897f092a04","nodeVersion":2}	1	2026-04-28 11:34:29.479+00	\N
132	wg2lnJe3gmOxJddG	1	nodeType	@blotato/n8n-nodes-blotato.blotato	{"nodeId":"4fb185bf-f237-4b71-8557-178f15f0caec","nodeVersion":2}	1	2026-04-28 11:34:29.479+00	\N
133	wg2lnJe3gmOxJddG	1	nodeType	@n8n/n8n-nodes-langchain.lmChatOpenAi	{"nodeId":"cb9939c6-1c5c-448b-ab3a-a66d90767cf2","nodeVersion":1.2}	1	2026-04-28 11:34:29.479+00	\N
134	wg2lnJe3gmOxJddG	1	nodeType	@n8n/n8n-nodes-langchain.toolThink	{"nodeId":"2c244851-7835-4f4a-8fe9-10a26acf6365","nodeVersion":1}	1	2026-04-28 11:34:29.479+00	\N
135	wg2lnJe3gmOxJddG	1	nodeType	@n8n/n8n-nodes-langchain.outputParserStructured	{"nodeId":"0695e935-93ac-48da-a893-1615ce22a6e7","nodeVersion":1.3}	1	2026-04-28 11:34:29.479+00	\N
136	wg2lnJe3gmOxJddG	1	nodeType	n8n-nodes-base.telegram	{"nodeId":"ff995af1-503e-4356-8e67-6392b4629496","nodeVersion":1.2}	1	2026-04-28 11:34:29.479+00	\N
137	wg2lnJe3gmOxJddG	1	nodeType	n8n-nodes-base.telegram	{"nodeId":"257eedc1-30c1-4e40-913b-24ceb018df28","nodeVersion":1.2}	1	2026-04-28 11:34:29.479+00	\N
138	wg2lnJe3gmOxJddG	1	nodeType	n8n-nodes-base.telegramTrigger	{"nodeId":"11f4ee14-912b-4a77-8696-7d36f7fc8a21","nodeVersion":1.2}	1	2026-04-28 11:34:29.479+00	\N
139	wg2lnJe3gmOxJddG	1	nodeType	n8n-nodes-base.set	{"nodeId":"45e0b8ee-b830-48bc-8a9a-a426a7afcd43","nodeVersion":3.4}	1	2026-04-28 11:34:29.479+00	\N
140	wg2lnJe3gmOxJddG	1	nodeType	@n8n/n8n-nodes-langchain.agent	{"nodeId":"a27e8e28-cb43-4b3f-a96e-e986a25209fb","nodeVersion":2}	1	2026-04-28 11:34:29.479+00	\N
141	wg2lnJe3gmOxJddG	1	nodeType	n8n-nodes-base.httpRequest	{"nodeId":"16902ea9-197e-4cac-936e-83c1fc226854","nodeVersion":4.2}	1	2026-04-28 11:34:29.479+00	\N
142	wg2lnJe3gmOxJddG	1	nodeType	n8n-nodes-base.wait	{"nodeId":"a7fffb23-dba4-4d1e-a42e-191a1414ec60","nodeVersion":1.1}	1	2026-04-28 11:34:29.479+00	\N
143	wg2lnJe3gmOxJddG	1	nodeType	n8n-nodes-base.httpRequest	{"nodeId":"67889216-2c0f-4ed8-ae54-8e7e7fdbac90","nodeVersion":4.2}	1	2026-04-28 11:34:29.479+00	\N
144	wg2lnJe3gmOxJddG	1	nodeType	@n8n/n8n-nodes-langchain.openAi	{"nodeId":"f6dda272-6129-4c04-b4c2-1e6bf5d156d8","nodeVersion":1.8}	1	2026-04-28 11:34:29.479+00	\N
145	wg2lnJe3gmOxJddG	1	nodeType	n8n-nodes-base.googleSheets	{"nodeId":"8b4c6b55-a0d7-4a19-b85c-1927ccb5eaa2","nodeVersion":4.6}	1	2026-04-28 11:34:29.479+00	\N
146	wg2lnJe3gmOxJddG	1	nodeType	n8n-nodes-base.code	{"nodeId":"30c415e0-58e0-48b9-b7e9-11dc5d979ac8","nodeVersion":2}	1	2026-04-28 11:34:29.479+00	\N
147	wg2lnJe3gmOxJddG	1	nodeType	n8n-nodes-base.stickyNote	{"nodeId":"61ce4a03-4104-4beb-bb16-0b2d2dde142d","nodeVersion":1}	1	2026-04-28 11:34:29.479+00	\N
148	wg2lnJe3gmOxJddG	1	nodeType	n8n-nodes-base.stickyNote	{"nodeId":"9f91c353-3ad6-498c-ba14-907bb91e208c","nodeVersion":1}	1	2026-04-28 11:34:29.479+00	\N
149	wg2lnJe3gmOxJddG	1	nodeType	n8n-nodes-base.stickyNote	{"nodeId":"3051b833-571a-4f0c-993a-ca8ffd03e476","nodeVersion":1}	1	2026-04-28 11:34:29.479+00	\N
150	wg2lnJe3gmOxJddG	1	nodeType	n8n-nodes-base.stickyNote	{"nodeId":"785aa7c8-8921-4b6b-8db3-8d55e2a42564","nodeVersion":1}	1	2026-04-28 11:34:29.479+00	\N
151	wg2lnJe3gmOxJddG	1	nodeType	n8n-nodes-base.telegram	{"nodeId":"fa25f6bf-d05b-4b8d-8a8a-b8684c601510","nodeVersion":1.2}	1	2026-04-28 11:34:29.479+00	\N
152	wg2lnJe3gmOxJddG	1	nodeType	n8n-nodes-base.googleDrive	{"nodeId":"7a362123-c86c-45f9-b80c-a5660f92da46","nodeVersion":3}	1	2026-04-28 11:34:29.479+00	\N
153	wg2lnJe3gmOxJddG	1	nodeType	n8n-nodes-base.googleSheets	{"nodeId":"a9614733-44e3-4580-95f8-a955d9136be4","nodeVersion":4.7}	1	2026-04-28 11:34:29.479+00	\N
154	wg2lnJe3gmOxJddG	1	nodeType	n8n-nodes-base.set	{"nodeId":"a8e85901-2451-4037-ba0c-aa2b229c9d0f","nodeVersion":3.4}	1	2026-04-28 11:34:29.479+00	\N
155	wg2lnJe3gmOxJddG	1	nodeType	n8n-nodes-base.httpRequest	{"nodeId":"ae9da8d7-f2c4-4ada-897c-651176cbfdb6","nodeVersion":4.2}	1	2026-04-28 11:34:29.479+00	\N
156	wg2lnJe3gmOxJddG	1	nodeType	@n8n/n8n-nodes-langchain.openAi	{"nodeId":"6527e03e-6417-45a5-95a8-2ef84b872df0","nodeVersion":1.8}	1	2026-04-28 11:34:29.479+00	\N
157	wg2lnJe3gmOxJddG	1	nodeType	n8n-nodes-base.googleSheets	{"nodeId":"6d78c44a-9073-4a2c-9a17-102c870b2162","nodeVersion":4.7}	1	2026-04-28 11:34:29.479+00	\N
158	wg2lnJe3gmOxJddG	1	nodeType	@n8n/n8n-nodes-langchain.outputParserStructured	{"nodeId":"efd41bb8-ecef-49ea-9051-ead169d6766b","nodeVersion":1.3}	1	2026-04-28 11:34:29.479+00	\N
159	wg2lnJe3gmOxJddG	1	nodeType	@n8n/n8n-nodes-langchain.lmChatOpenAi	{"nodeId":"96a49fe4-d013-42c8-9ae8-11eb713e132f","nodeVersion":1.2}	1	2026-04-28 11:34:29.479+00	\N
160	wg2lnJe3gmOxJddG	1	nodeType	@n8n/n8n-nodes-langchain.agent	{"nodeId":"f6599d80-4301-4dd1-bc38-1c39e57e21cb","nodeVersion":2.2}	1	2026-04-28 11:34:29.479+00	\N
161	wg2lnJe3gmOxJddG	1	nodeType	n8n-nodes-base.httpRequest	{"nodeId":"80274aa5-bdf0-49bf-9980-0624d99d68ef","nodeVersion":4.2}	1	2026-04-28 11:34:29.479+00	\N
162	wg2lnJe3gmOxJddG	1	nodeType	n8n-nodes-base.wait	{"nodeId":"e132487d-da8c-4850-9d3f-9e057e9bde64","nodeVersion":1.1}	1	2026-04-28 11:34:29.479+00	\N
163	wg2lnJe3gmOxJddG	1	nodeType	n8n-nodes-base.httpRequest	{"nodeId":"2c7ffce1-8ace-418d-9738-c659f4554980","nodeVersion":4.2}	1	2026-04-28 11:34:29.479+00	\N
164	wg2lnJe3gmOxJddG	1	nodeType	n8n-nodes-base.googleSheets	{"nodeId":"ec725aa0-fd30-4d98-b984-0228873db428","nodeVersion":4.6}	1	2026-04-28 11:34:29.479+00	\N
165	wg2lnJe3gmOxJddG	1	nodeType	n8n-nodes-base.telegram	{"nodeId":"abafa8c6-55a0-488c-970e-d2a969ad7959","nodeVersion":1.2}	1	2026-04-28 11:34:29.479+00	\N
166	wg2lnJe3gmOxJddG	1	nodeType	n8n-nodes-base.stickyNote	{"nodeId":"77030cb3-3246-41d5-bcbc-74f82bdd501b","nodeVersion":1}	1	2026-04-28 11:34:29.479+00	\N
200	CD2GddIS6pD1N23E	3	nodeType	n8n-nodes-base.manualTrigger	{"nodeId":"ff5a732c-7d53-443e-adf0-53e433fc7a50","nodeVersion":1}	1	2026-05-07 07:00:48.541+00	\N
201	CD2GddIS6pD1N23E	3	nodeType	n8n-nodes-base.httpRequest	{"nodeId":"ae47912b-48d0-4628-80bb-e871690e57d9","nodeVersion":4.4}	1	2026-05-07 07:00:48.541+00	\N
187	AlrynH2aZBv1h5NT	11	nodeType	n8n-nodes-base.scheduleTrigger	{"nodeId":"b38e6f47-0ed0-45d9-a630-e43103d9b9a4","nodeVersion":1.2}	1	2026-05-05 10:38:40.595+00	c2fe07de-5bfc-470d-94ed-072de0da5de1
188	AlrynH2aZBv1h5NT	11	nodeType	n8n-nodes-base.httpRequest	{"nodeId":"9616ca6d-5bb5-4253-a71f-8b0ce2579597","nodeVersion":4.2}	1	2026-05-05 10:38:40.595+00	c2fe07de-5bfc-470d-94ed-072de0da5de1
189	AlrynH2aZBv1h5NT	11	nodeType	n8n-nodes-base.code	{"nodeId":"e8edd62b-4643-469c-9e33-08d99f49cbd6","nodeVersion":2}	1	2026-05-05 10:38:40.595+00	c2fe07de-5bfc-470d-94ed-072de0da5de1
190	AlrynH2aZBv1h5NT	11	nodeType	n8n-nodes-base.code	{"nodeId":"c35065a3-6aa5-4045-be9b-09be07881794","nodeVersion":2}	1	2026-05-05 10:38:40.595+00	c2fe07de-5bfc-470d-94ed-072de0da5de1
191	AlrynH2aZBv1h5NT	11	nodeType	n8n-nodes-base.httpRequest	{"nodeId":"8e6ca49a-ea77-4b21-921b-c447b52a6954","nodeVersion":4.2}	1	2026-05-05 10:38:40.595+00	c2fe07de-5bfc-470d-94ed-072de0da5de1
\.


--
-- Data for Name: workflow_entity; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.workflow_entity (name, active, nodes, connections, "createdAt", "updatedAt", settings, "staticData", "pinData", "versionId", "triggerCount", id, meta, "parentFolderId", "isArchived", "versionCounter", description, "activeVersionId") FROM stdin;
DevSignal — Main Pipeline	f	[{"parameters":{"rule":{"interval":[{"field":"hours","hoursInterval":12}]}},"id":"a8d8e941-839c-4994-8e5d-590a17b21236","name":"Every 12 Hours","type":"n8n-nodes-base.scheduleTrigger","typeVersion":1.2,"position":[-480,112]},{"parameters":{"jsCode":"// Log success to console\\nconst output = $input.first().json;\\nconst stdout = output.stdout || '';\\nconsole.log('Pipeline completed successfully');\\nconsole.log('Output length:', stdout.length, 'chars');\\n\\n// Return summary\\nreturn [{\\n  json: {\\n    status: 'success',\\n    timestamp: new Date().toISOString(),\\n    output_preview: stdout.slice(-500)\\n  }\\n}];"},"id":"6cbb17c4-be30-4171-b346-ab37c0b0fee5","name":"Log Success","type":"n8n-nodes-base.code","typeVersion":2,"position":[0,0]},{"parameters":{"jsCode":"// Extract error info\\nconst errorData = $input.first().json;\\nconst stdout   = errorData.stdout || '';\\nconst stderr   = errorData.stderr || '';\\nconst exitCode = errorData.exitCode || 'unknown';\\n\\nconst errorMsg = stderr || stdout || 'Unknown error';\\n\\nconsole.error('Pipeline FAILED:', errorMsg.slice(0, 500));\\n\\nreturn [{\\n  json: {\\n    status:    'failed',\\n    exit_code: exitCode,\\n    error_msg: errorMsg.slice(0, 1000),\\n    timestamp: new Date().toISOString()\\n  }\\n}];"},"id":"443da55f-7aaf-4752-b084-2415fee40658","name":"Parse Error","type":"n8n-nodes-base.code","typeVersion":2,"position":[0,224]},{"parameters":{"method":"POST","url":"=https://api.telegram.org/bot{{ $env.TELEGRAM_BOT_TOKEN }}/sendMessage","sendBody":true,"bodyParameters":{"parameters":[{"name":"chat_id","value":"={{ $env.TELEGRAM_CHAT_ID }}"},{"name":"text","value":"=<b>DevSignal — Pipeline Failed</b>\\n\\nTime: {{ $json.timestamp }}\\nExit: {{ $json.exit_code }}\\n\\n<code>{{ $json.error_msg.slice(0, 500) }}</code>"},{"name":"parse_mode","value":"HTML"}]},"options":{}},"id":"7567a15f-1fa3-443b-aa40-ead578f52fe0","name":"Telegram Error Alert","type":"n8n-nodes-base.httpRequest","typeVersion":4.2,"position":[240,224]},{"parameters":{"command":"bash /app/run_pipeline.sh 2>&1"},"id":"02a864ff-c4ea-484f-a935-05dea56f2cfd","name":"Run Pipeline","type":"n8n-nodes-base.executeCommand","typeVersion":1,"position":[-208,96],"onError":"continueErrorOutput"}]	{"Parse Error":{"main":[[{"node":"Telegram Error Alert","type":"main","index":0}]]},"Every 12 Hours":{"main":[[]]},"Log Success":{"main":[[]]}}	2026-04-24 13:57:46.222+00	2026-05-07 07:24:09.301+00	{"executionOrder":"v1","binaryMode":"separate"}	\N	{}	ac4286bc-4dba-4722-994b-0b58812c8d3f	0	irl7JgZwJOTujHbm	\N	\N	t	23	\N	\N
Generate AI viral videos with NanoBanana & VEO3, shared on socials via Blotato	f	[{"parameters":{"content":"# 📑 STEP 5 — Auto-Post to All Platforms\\n\\n","height":832,"width":1344,"color":4},"id":"101bdee1-4de4-4b5e-9170-4d490d4e8128","name":"Sticky Note3","type":"n8n-nodes-base.stickyNote","position":[2320,880],"typeVersion":1},{"parameters":{"mediaUrl":"={{ $('Download Video from VEO3').item.json.data.response.resultUrls[0] }}","resource":"media"},"id":"db2db976-7988-4939-a931-b6b2b98570aa","name":"Upload Video to BLOTATO","type":"@blotato/n8n-nodes-blotato.blotato","position":[2384,1504],"typeVersion":2,"credentials":{}},{"parameters":{"options":{},"platform":"youtube","accountId":{"__rl":true,"mode":"list","value":""},"postContentText":"={{ $('Save Caption Video to Google Sheets').item.json['CAPTION VIDEO'] }}","postContentMediaUrls":"={{ $json.url }}","postCreateYoutubeOptionTitle":"={{ $('Save Caption Video to Google Sheets').item.json['TITRE VIDEO'] }}","postCreateYoutubeOptionPrivacyStatus":"private","postCreateYoutubeOptionShouldNotifySubscribers":false},"id":"6866a654-e6a7-4543-b98a-8288f9d04b47","name":"Youtube","type":"@blotato/n8n-nodes-blotato.blotato","position":[3008,1296],"typeVersion":2,"credentials":{}},{"parameters":{"options":{},"platform":"tiktok","accountId":{"__rl":true,"mode":"list","value":""},"postContentText":"={{ $('Save Caption Video to Google Sheets').item.json['CAPTION VIDEO'] }}","postContentMediaUrls":"={{ $json.url }}"},"id":"a1b51932-2e2c-4e32-a37a-7ce94620cdd9","name":"Tiktok","type":"@blotato/n8n-nodes-blotato.blotato","position":[2640,1120],"typeVersion":2,"credentials":{}},{"parameters":{"mode":"chooseBranch","numberInputs":9},"id":"2c6cb6a6-e4b2-470d-8afb-b2c03b72e97b","name":"Merge","type":"n8n-nodes-base.merge","position":[3296,1200],"typeVersion":3.2},{"parameters":{"operation":"appendOrUpdate","documentId":{"__rl":true,"mode":"id","value":""},"sheetName":{"__rl":true,"mode":"id","value":""}},"id":"bee496d6-fc2d-4f1c-812f-9d6be08154a7","name":"Update Status to \\"DONE\\"","type":"n8n-nodes-base.googleSheets","position":[3472,1312],"typeVersion":4.5},{"parameters":{"options":{},"platform":"linkedin","accountId":{"__rl":true,"mode":"list","value":""},"postContentText":"={{ $('Save Caption Video to Google Sheets').item.json['CAPTION VIDEO'] }}","postContentMediaUrls":"={{ $json.url }}"},"id":"5f7344d8-a277-457b-a33f-c48e2ced1e49","name":"Linkedin","type":"@blotato/n8n-nodes-blotato.blotato","position":[2832,1120],"typeVersion":2,"credentials":{}},{"parameters":{"options":{},"platform":"facebook","accountId":{"__rl":true,"mode":"list","value":""},"facebookPageId":{"__rl":true,"mode":"list","value":""},"postContentText":"={{ $('Save Caption Video to Google Sheets').item.json['CAPTION VIDEO'] }}","postContentMediaUrls":"={{ $json.url }}"},"id":"31bc2347-2457-4fad-8436-09282df89609","name":"Facebook","type":"@blotato/n8n-nodes-blotato.blotato","position":[3008,1120],"typeVersion":2,"credentials":{}},{"parameters":{"options":{},"accountId":{"__rl":true,"mode":"list","value":""},"postContentText":"={{ $('Save Caption Video to Google Sheets').item.json['CAPTION VIDEO'] }}","postContentMediaUrls":"={{ $json.url }}"},"id":"06e29e46-c3ce-4c9e-825d-39df924a607d","name":"Instagram","type":"@blotato/n8n-nodes-blotato.blotato","position":[2640,1296],"typeVersion":2,"credentials":{}},{"parameters":{"options":{},"platform":"threads","accountId":{"__rl":true,"mode":"list","value":""},"postContentText":"={{ $('Save Caption Video to Google Sheets').item.json['CAPTION VIDEO'] }}","postContentMediaUrls":"={{ $json.url }}"},"id":"3f7560c8-3e4a-4d62-bf62-e8d543df8026","name":"Threads","type":"@blotato/n8n-nodes-blotato.blotato","position":[2640,1504],"typeVersion":2,"credentials":{}},{"parameters":{"options":{},"platform":"bluesky","accountId":{"__rl":true,"mode":"list","value":""},"postContentText":"={{ $('Save Caption Video to Google Sheets').item.json['CAPTION VIDEO'] }}","postContentMediaUrls":"={{ $json.url }}"},"id":"3e4b6251-7c56-40ca-8fb6-4b77c910a2e6","name":"Bluesky","type":"@blotato/n8n-nodes-blotato.blotato","position":[2832,1504],"typeVersion":2,"credentials":{}},{"parameters":{"options":{},"platform":"pinterest","accountId":{"__rl":true,"mode":"list","value":""},"postContentText":"={{ $('Save Caption Video to Google Sheets').item.json['CAPTION VIDEO'] }}","pinterestBoardId":{"__rl":true,"mode":"id","value":""},"postContentMediaUrls":"={{ $json.url }}"},"id":"61f5f513-b7ec-40ca-a4a1-1b897f092a04","name":"Pinterest","type":"@blotato/n8n-nodes-blotato.blotato","position":[3008,1504],"typeVersion":2,"credentials":{}},{"parameters":{"options":{},"platform":"twitter","accountId":{"__rl":true,"mode":"list","value":""},"postContentText":"={{ $('Save Caption Video to Google Sheets').item.json['CAPTION VIDEO'] }}","postContentMediaUrls":"={{ $json.url }}"},"id":"4fb185bf-f237-4b71-8557-178f15f0caec","name":"Twitter (X)","type":"@blotato/n8n-nodes-blotato.blotato","position":[2832,1296],"typeVersion":2,"credentials":{}},{"parameters":{"model":{"__rl":true,"mode":"list","value":""},"options":{}},"id":"cb9939c6-1c5c-448b-ab3a-a66d90767cf2","name":"OpenAI Chat Model","type":"@n8n/n8n-nodes-langchain.lmChatOpenAi","position":[1840,1216],"typeVersion":1.2},{"parameters":{},"id":"2c244851-7835-4f4a-8fe9-10a26acf6365","name":"Think","type":"@n8n/n8n-nodes-langchain.toolThink","position":[1984,1216],"typeVersion":1},{"parameters":{"jsonSchemaExample":"{\\n  \\"title\\": \\"string\\",\\n  \\"final_prompt\\": \\"string\\"\\n}\\n"},"id":"0695e935-93ac-48da-a893-1615ce22a6e7","name":"Structured Output Parser","type":"@n8n/n8n-nodes-langchain.outputParserStructured","position":[2128,1216],"typeVersion":1.3},{"parameters":{"chatId":"={{ $('Telegram Trigger: Receive Video Idea').item.json.message.chat.id }}","text":"=Url VIDEO : {{ $('Download Video from VEO3').item.json.data.response.resultUrls[0] }}","additionalFields":{}},"id":"ff995af1-503e-4356-8e67-6392b4629496","name":"Send Video URL via Telegram","type":"n8n-nodes-base.telegram","position":[2368,1008],"webhookId":"ea6e5974-1930-4b67-a51b-16249a9ed8bd","typeVersion":1.2},{"parameters":{"operation":"sendVideo","chatId":"={{ $json.result.chat.id }}","file":"={{ $('Save Caption Video to Google Sheets').item.json['URL VIDEO FINAL'] }}","additionalFields":{}},"id":"257eedc1-30c1-4e40-913b-24ceb018df28","name":"Send Final Video Preview","type":"n8n-nodes-base.telegram","position":[2384,1248],"webhookId":"443fd41d-a051-45bf-ad68-173197dba26b","typeVersion":1.2},{"parameters":{"updates":["message"],"additionalFields":{}},"id":"11f4ee14-912b-4a77-8696-7d36f7fc8a21","name":"Telegram Trigger: Receive Video Idea","type":"n8n-nodes-base.telegramTrigger","position":[1152,432],"webhookId":"26dbe6f5-5197-4b2b-9e32-8060f2119686","typeVersion":1.2},{"parameters":{"assignments":{"assignments":[{"id":"cc2e0500-57b1-4615-82cb-1c950e5f2ec4","name":"json_master","type":"string","value":"={\\n  \\"description\\": \\"Brief narrative description of the scene, focusing on key visual storytelling and product transformation.\\",\\n  \\"style\\": \\"cinematic | photorealistic | stylized | gritty | elegant\\",\\n  \\"camera\\": {\\n    \\"type\\": \\"fixed | dolly | Steadicam | crane combo\\",\\n    \\"movement\\": \\"describe any camera moves like slow push-in, pan, orbit\\",\\n    \\"lens\\": \\"optional lens type or focal length for cinematic effect\\"\\n  },\\n  \\"lighting\\": {\\n    \\"type\\": \\"natural | dramatic | high-contrast\\",\\n    \\"sources\\": \\"key lighting sources (sunset, halogen, ambient glow...)\\",\\n    \\"FX\\": \\"optional VFX elements like fog, reflections, flares\\"\\n  },\\n  \\"environment\\": {\\n    \\"location\\": \\"describe location or room (kitchen, desert, basketball court...)\\",\\n    \\"set_pieces\\": [\\n      \\"list of key background or prop elements\\",\\n      \\"e.g. hardwood floors, chain-link fence, velvet surface\\"\\n    ],\\n    \\"mood\\": \\"describe the ambient atmosphere (moody, clean, epic...)\\"\\n  },\\n  \\"elements\\": [\\n    \\"main physical items involved (product box, accessories, vehicles...)\\",\\n    \\"include brand visibility (logos, packaging, texture...)\\"\\n  ],\\n  \\"subject\\": {\\n    \\"character\\": {\\n      \\"description\\": \\"optional – physical description, outfit\\",\\n      \\"pose\\": \\"optional – position or gesture\\",\\n      \\"lip_sync_line\\": \\"optional – spoken line if there’s a voiceover\\"\\n    },\\n    \\"product\\": {\\n      \\"brand\\": \\"Brand name\\",\\n      \\"model\\": \\"Product model or name\\",\\n      \\"action\\": \\"description of product transformation or assembly\\"\\n    }\\n  },\\n  \\"motion\\": {\\n    \\"type\\": \\"e.g. transformation, explosion, vortex\\",\\n    \\"details\\": \\"step-by-step visual flow of how elements move or evolve\\"\\n  },\\n  \\"VFX\\": {\\n    \\"transformation\\": \\"optional – describe style (neon trails, motion blur...)\\",\\n    \\"impact\\": \\"optional – e.g. shockwave, glow, distortion\\",\\n    \\"particles\\": \\"optional – embers, sparks, thread strands...\\",\\n    \\"environment\\": \\"optional – VFX affecting the scene (ripples, wind...)\\"\\n  },\\n  \\"audio\\": {\\n    \\"music\\": \\"optional – cinematic score, trap beat, ambient tone\\",\\n    \\"sfx\\": [\\n      \\"list of sound effects (zip, pop, woosh...)\\"\\n    ],\\n    \\"ambience\\": \\"optional – background soundscape (traffic, wind...)\\",\\n    \\"voiceover\\": {\\n      \\"delivery\\": \\"tone and style (confident, whisper, deep...)\\",\\n      \\"line\\": \\"text spoken if applicable\\"\\n    }\\n  },\\n  \\"ending\\": \\"Final shot description – what is seen or felt at the end (freeze frame, logo pulse, glow...)\\",\\n  \\"text\\": \\"none | overlay | tagline | logo pulse at end only\\",\\n  \\"format\\": \\"16:9 | 4k | vertical\\",\\n  \\"keywords\\": [\\n    \\"brand\\",\\n    \\"scene style\\",\\n    \\"motion type\\",\\n    \\"camera style\\",\\n    \\"sound mood\\",\\n    \\"target theme\\"\\n  ]\\n}\\n"}]},"options":{}},"id":"45e0b8ee-b830-48bc-8a9a-a426a7afcd43","name":"Set Master Prompt","type":"n8n-nodes-base.set","position":[1600,992],"typeVersion":3.4},{"parameters":{"promptType":"define","text":"=Create a UGC-style video prompt using both the reference image and the user description.  \\n\\n**Inputs**  \\n- User description (optional):  \\n  `{{ $('Telegram Trigger: Receive Video Idea').item.json.message.caption }}`  \\n- Reference image analysis (stay strictly faithful to what’s visible):  \\n  `{{ $('Google Sheets: Update Image Description').item.json['IMAGE DESCRIPTION'] }}`  \\n\\n**Rules**  \\n- Keep the style casual, authentic, and realistic. Avoid studio-like or cinematic language.  \\n- Default model: `veo3_fast` (unless otherwise specified).  \\n- Output only **one JSON object** with the key: `video_prompt`.  \\n","hasOutputParser":true,"options":{"systemMessage":"=system_prompt:\\n  ## SYSTEM PROMPT: Structured Video Ad Prompt Generator\\n  A - Ask:\\n    Generate a structured video ad prompt for cinematic generation, strictly based on the master schema provided in: {{ $json.json_master }}.\\n    The final result must be a JSON object with exactly two top-level keys: `title` and `final_prompt`.\\n\\n  G - Guidance:\\n    role: Creative Director\\n    output_count: 1\\n    character_limit: None\\n    constraints:\\n      - The output must be valid JSON.\\n      - The `title` field should contain a short, descriptive and unique title (max 15 words).\\n      - The `final_prompt` field must contain a **single-line JSON string** that follows the exact structure of {{ $json.json_master }} with all fields preserved.\\n      - Do not include any explanations, markdown, or extra text — only the JSON object.\\n      - Escape all inner quotes in the `final_prompt` string so it is valid as a stringified JSON inside another JSON.\\n    tool_usage:\\n      - Ensure consistent alignment across all fields (camera, lighting, motion, etc.).\\n      - Maintain full structure even for optional fields (use \\"none\\", \\"\\", or [] as needed).\\n\\n  N - Notation:\\n    format: JSON\\n    expected_output:\\n      {\\n        \\"title\\": \\"A unique short title for the scene\\",\\n        \\"final_prompt\\": \\"{...stringified JSON of the full prompt...}\\"\\n      }\\n\\n"}},"id":"a27e8e28-cb43-4b3f-a96e-e986a25209fb","name":"AI Agent: Generate Video Script","type":"@n8n/n8n-nodes-langchain.agent","position":[1920,992],"typeVersion":2},{"parameters":{"method":"POST","url":"https://api.kie.ai/api/v1/veo/generate","authentication":"genericCredentialType","genericAuthType":"httpHeaderAuth","sendBody":true,"contentType":"raw","rawContentType":"application/json","body":"={\\n  \\"prompt\\": {{ $json.prompt }},\\n  \\"model\\": \\"{{ $('Google Sheets: Read Video Parameters (CONFIG)').item.json.model }}\\",\\n  \\"aspectRatio\\": \\"{{ $json.aspectRatio }}\\",\\n  \\"imageUrls\\": [\\n    \\"{{ $('Download Edited Image').item.json.images[0].url }}\\"\\n  ]\\n}","options":{}},"id":"16902ea9-197e-4cac-936e-83c1fc226854","name":"Generate Video with VEO3","type":"n8n-nodes-base.httpRequest","position":[1200,1504],"typeVersion":4.2},{"parameters":{"amount":20},"id":"a7fffb23-dba4-4d1e-a42e-191a1414ec60","name":"Wait for VEO3 Rendering","type":"n8n-nodes-base.wait","position":[1408,1504],"webhookId":"f6d814f3-4eb8-4629-a920-134cfa4ea03b","typeVersion":1.1},{"parameters":{"url":"https://api.kie.ai/api/v1/veo/record-info","authentication":"genericCredentialType","genericAuthType":"httpHeaderAuth","sendQuery":true,"queryParameters":{"parameters":[{"name":"taskId","value":"={{ $('Generate Video with VEO3').item.json.data.taskId }}"}]},"options":{}},"id":"67889216-2c0f-4ed8-ae54-8e7e7fdbac90","name":"Download Video from VEO3","type":"n8n-nodes-base.httpRequest","position":[1616,1504],"typeVersion":4.2},{"parameters":{"modelId":{"__rl":true,"mode":"list","value":""},"messages":{"values":[{"content":"=You are rewriting a TikTok video script, caption, and overlay —\\nnot inventing a new one. You must follow this format and obey\\nthese rules strictly.\\n---\\n### CONTEXT:\\nHere is the content idea to use:{{ $('Telegram Trigger: Receive Video Idea').item.json.message.caption }}\\n\\nand the Title is : {{ $('AI Agent: Generate Video Script').item.json.output.title }}\\n\\n\\nWrite the caption text using the topic.\\n\\n---\\n- MUST be under 200 characters (yes \\"Characters\\" not wordcount)\\nthis is an absolute MUST, no more than 200 characters!!! \\n\\n### FINAL OUTPUT FORMAT (no markdown formatting):\\n\\nDO NOT return any explanations. Only return the Caption Text\\n"}]},"options":{}},"id":"f6dda272-6129-4c04-b4c2-1e6bf5d156d8","name":"Rewrite Caption with GPT-4o","type":"@n8n/n8n-nodes-langchain.openAi","position":[1776,1504],"typeVersion":1.8},{"parameters":{"operation":"appendOrUpdate","documentId":{"__rl":true,"mode":"id","value":""},"sheetName":{"__rl":true,"mode":"id","value":""}},"id":"8b4c6b55-a0d7-4a19-b85c-1927ccb5eaa2","name":"Save Caption Video to Google Sheets","type":"n8n-nodes-base.googleSheets","position":[2080,1504],"typeVersion":4.6},{"parameters":{"jsCode":"const structuredPrompt = $input.first().json.output.final_prompt;\\nreturn {\\n  json: {\\n    prompt: JSON.stringify(structuredPrompt), // this escapes it correctly!\\n    model: \\"veo3_fast\\",\\n    aspectRatio: \\"16:9\\"\\n  }\\n};\\n"},"id":"30c415e0-58e0-48b9-b7e9-11dc5d979ac8","name":"Format Prompt","type":"n8n-nodes-base.code","position":[1200,1200],"typeVersion":2},{"parameters":{"content":"# 📑 STEP 3 — Generate Video Ad Script","height":460,"width":1180},"id":"61ce4a03-4104-4beb-bb16-0b2d2dde142d","name":"Sticky Note2","type":"n8n-nodes-base.stickyNote","position":[1088,880],"typeVersion":1},{"parameters":{"content":"# 📑 STEP 4 — Generate Video with VEO3","height":320,"width":1180},"id":"9f91c353-3ad6-498c-ba14-907bb91e208c","name":"Sticky Note4","type":"n8n-nodes-base.stickyNote","position":[1088,1392],"typeVersion":1},{"parameters":{"content":"# 📑 STEP 1 — Collect Idea & Image","height":592,"width":1184},"id":"3051b833-571a-4f0c-993a-ca8ffd03e476","name":"Sticky Note","type":"n8n-nodes-base.stickyNote","position":[1088,240],"typeVersion":1},{"parameters":{"content":"# 📑 STEP 2 — Create Image with NanoBanana\\n","height":592,"width":1328},"id":"785aa7c8-8921-4b6b-8db3-8d55e2a42564","name":"Sticky Note1","type":"n8n-nodes-base.stickyNote","position":[2320,240],"typeVersion":1},{"parameters":{"resource":"file","fileId":"={{ $json.message.photo[2].file_id }}","additionalFields":{}},"id":"fa25f6bf-d05b-4b8d-8a8a-b8684c601510","name":"Telegram: Get Image File","type":"n8n-nodes-base.telegram","position":[1584,304],"webhookId":"06ceb31d-dcd9-4a9a-bbbe-a7bf7ae0ad4a","typeVersion":1.2},{"parameters":{"name":"={{ $('Telegram Trigger: Receive Video Idea').item.json.message.photo[2].file_unique_id }}","driveId":{"__rl":true,"mode":"id","value":""},"folderId":{"__rl":true,"mode":"id","value":""},"options":{}},"id":"7a362123-c86c-45f9-b80c-a5660f92da46","name":"Google Drive: Upload Image","type":"n8n-nodes-base.googleDrive","position":[1600,496],"typeVersion":3},{"parameters":{"operation":"appendOrUpdate","documentId":{"__rl":true,"mode":"id","value":""},"sheetName":{"__rl":true,"mode":"id","value":""}},"id":"a9614733-44e3-4580-95f8-a955d9136be4","name":"Google Sheets: Log Image & Caption","type":"n8n-nodes-base.googleSheets","position":[1600,672],"typeVersion":4.7},{"parameters":{"assignments":{"assignments":[{"id":"af62651a-3fc8-419d-908b-6514f6f4bcb3","name":"YOUR_BOT_TOKEN","type":"string","value":""}]},"options":{}},"id":"a8e85901-2451-4037-ba0c-aa2b229c9d0f","name":"Set: Bot Token (Placeholder)","type":"n8n-nodes-base.set","position":[1840,432],"typeVersion":3.4},{"parameters":{"url":"=https://api.telegram.org/bot{{ $json.YOUR_BOT_TOKEN }}/getFile?file_id={{ $('Telegram Trigger: Receive Video Idea').item.json.message.photo[3].file_id }}","options":{}},"id":"ae9da8d7-f2c4-4ada-897c-651176cbfdb6","name":"Telegram API: Get File URL","type":"n8n-nodes-base.httpRequest","position":[2032,432],"typeVersion":4.2},{"parameters":{"resource":"image","operation":"analyze","modelId":{"__rl":true,"mode":"list","value":""},"text":"=You are an image analysis assistant.\\n\\nYour task is to analyze the given image and output results **only in YAML format**. Do not add explanations, comments, or extra text outside YAML.\\n\\nRules:\\n\\n- If the image depicts a **product**, return:\\n    \\n    ```yaml\\n    brand_name: (brand if visible or inferable)\\n    color_scheme:\\n      - hex: (hex code of each prominent color)\\n        name: (descriptive name of the color)\\n    font_style: (serif/sans-serif, bold/thin, etc.)\\n    visual_description: (1–2 sentences summarizing what is seen, ignoring the background)\\n    \\n    ```\\n    \\n- If the image depicts a **character**, return:\\n    \\n    ```yaml\\n    character_name: (name if visible or inferable, else \\"unknown\\")\\n    color_scheme:\\n      - hex: (hex code of each prominent color on the character)\\n        name: (descriptive name of the color)\\n    outfit_style: (clothing style, accessories, or notable features)\\n    visual_description: (1–2 sentences summarizing what the character looks like, ignoring the background)\\n    \\n    ```\\n    \\n- If the image depicts **both**, return **both sections** in YAML.\\n\\nOnly output valid YAML. No explanations.","imageUrls":"=https://api.telegram.org/file/bot{{ $('Set: Bot Token (Placeholder)').item.json.YOUR_BOT_TOKEN }}/{{ $json.result.file_path }}","options":{}},"id":"6527e03e-6417-45a5-95a8-2ef84b872df0","name":"OpenAI Vision: Analyze Reference Image","type":"@n8n/n8n-nodes-langchain.openAi","position":[2448,432],"typeVersion":1.8},{"parameters":{"operation":"appendOrUpdate","documentId":{"__rl":true,"mode":"id","value":""},"sheetName":{"__rl":true,"mode":"id","value":""}},"id":"6d78c44a-9073-4a2c-9a17-102c870b2162","name":"Google Sheets: Update Image Description","type":"n8n-nodes-base.googleSheets","position":[2688,432],"typeVersion":4.7},{"parameters":{"jsonSchemaExample":"{\\n\\t\\"image_prompt\\": \\"string\\"\\n}"},"id":"efd41bb8-ecef-49ea-9051-ead169d6766b","name":"LLM: Structured Output Parser","type":"@n8n/n8n-nodes-langchain.outputParserStructured","position":[3072,672],"typeVersion":1.3},{"parameters":{"model":{"__rl":true,"mode":"list","value":""},"options":{}},"id":"96a49fe4-d013-42c8-9ae8-11eb713e132f","name":"LLM: OpenAI Chat","type":"@n8n/n8n-nodes-langchain.lmChatOpenAi","position":[2864,672],"typeVersion":1.2},{"parameters":{"promptType":"define","text":"=Your task is to create an image prompt following the system guidelines.  \\nEnsure that the reference image is represented as **accurately as possible**, including all text elements.  \\n\\nUse the following inputs:  \\n\\n- **User’s description:**  \\n{{ $json.CAPTION }}\\n\\n- **Reference image description:**  \\n{{ $json['IMAGE DESCRIPTION'] }}\\n","hasOutputParser":true,"options":{"systemMessage":"=ROLE: UGC Image Prompt Builder  \\n\\nGOAL:  \\nGenerate one concise, natural, and realistic image prompt (≤120 words) from a given product or reference image. The prompt must simulate authentic UGC (user-generated content) photography.  \\n\\nRULES:  \\n- Always output **one JSON object only** with the key:  \\n  - `image_prompt`: (string with full description)  \\n- Do **not** add commentary, metadata, or extra keys. JSON only.  \\n\\nSTYLE GUIDELINES:  \\n- Tone: casual, unstaged, lifelike, handheld snapshot.  \\n- Camera cues: include at least 2–3 (e.g., phone snapshot, handheld framing, off-center composition, natural indoor light, soft shadows, slight motion blur, auto exposure, unpolished look, mild grain).  \\n- Realism: embrace imperfections (wrinkles, stray hairs, skin texture, clutter, smudges).  \\n- Packaging/Text: preserve exactly as visible. Never invent claims, numbers, or badges.  \\n- Diversity: if people appear but are unspecified, vary gender/ethnicity naturally; default age range = 21–38.  \\n- Setting: default to real-world everyday spaces (home, street, store, gym, office).  \\n\\nSAFETY:  \\n- No copyrighted character names.  \\n- No dialogue or scripts. Only describe scenes.  \\n\\nOUTPUT CONTRACT:  \\n- JSON only, no prose outside.  \\n- Max 120 words in `image_prompt`.  \\n- Must cover: subject, action, mood, setting, style/camera, colors, and text accuracy.  \\n\\nCHECKLIST BEFORE OUTPUT:  \\n- Natural handheld tone?  \\n- At least 2 camera cues included?  \\n- Product text preserved exactly?  \\n- Only JSON returned?  \\n\\n---  \\n\\n### Example  \\n\\nGood Example :  \\n```json\\n{ \\"image_prompt\\": \\"a young adult casually holding a skincare tube near a bathroom mirror; action: dabs small amount on the back of the hand; mood: easy morning; setting: small apartment bathroom with towel on rack and toothbrush cup; style/camera: phone snapshot, handheld framing, off-center composition, natural window light, slight motion blur, mild grain; colors: soft whites and mint label; text accuracy: keep every word on the tube exactly as visible, no added claims\\" }\\n"}},"id":"f6599d80-4301-4dd1-bc38-1c39e57e21cb","name":"Generate Image Prompt","type":"@n8n/n8n-nodes-langchain.agent","position":[2912,432],"typeVersion":2.2},{"parameters":{"method":"POST","url":"https://queue.fal.run/fal-ai/nano-banana/edit","authentication":"genericCredentialType","genericAuthType":"httpHeaderAuth","sendBody":true,"specifyBody":"json","jsonBody":"={\\n\\t\\"prompt\\": \\"{{ $json.output.image_prompt.replace(/\\\\\\"/g, '\\\\\\\\\\\\\\"').replace(/\\\\n/g, '\\\\\\\\n') }}\\",\\n\\"image_urls\\": [\\"{{ $('Google Drive: Upload Image').item.json.webContentLink }}\\"]\\n\\n}\\n\\n","options":{}},"id":"80274aa5-bdf0-49bf-9980-0624d99d68ef","name":"NanoBanana: Create Image","type":"n8n-nodes-base.httpRequest","position":[3248,432],"typeVersion":4.2},{"parameters":{"amount":20},"id":"e132487d-da8c-4850-9d3f-9e057e9bde64","name":"Wait for Image Edit","type":"n8n-nodes-base.wait","position":[3456,432],"webhookId":"df52d997-45c4-431f-bdf6-89dd25027b5b","typeVersion":1.1},{"parameters":{"url":"={{ $json.response_url }}","authentication":"genericCredentialType","genericAuthType":"httpHeaderAuth","options":{}},"id":"2c7ffce1-8ace-418d-9738-c659f4554980","name":"Download Edited Image","type":"n8n-nodes-base.httpRequest","position":[3456,656],"typeVersion":4.2},{"parameters":{"documentId":{"__rl":true,"mode":"id","value":""},"sheetName":{"__rl":true,"mode":"id","value":""}},"id":"ec725aa0-fd30-4d98-b984-0228873db428","name":"Google Sheets: Read Video Parameters (CONFIG)","type":"n8n-nodes-base.googleSheets","position":[1392,992],"typeVersion":4.6},{"parameters":{"chatId":"={{ $('Telegram Trigger: Receive Video Idea').item.json.message.chat.id }}","text":"Published","additionalFields":{}},"id":"abafa8c6-55a0-488c-970e-d2a969ad7959","name":"Telegram: Send notification","type":"n8n-nodes-base.telegram","position":[3472,1520],"webhookId":"2f4a4bc1-99de-4e93-8523-dd8c6499b893","typeVersion":1.2},{"parameters":{"content":"# 🎬 Generate AI viral videos with NanoBanana & VEO3, shared on socials via Blotato (By Dr. Firas)\\n\\n\\n# 🎥 Full Tutorial :\\n[![AI Voice Agent Preview](https://www.dr-firas.com/nanobanana.png)](https://youtu.be/nlwpbXQqNQ4)\\n\\n---\\n\\n# 📘 Documentation  \\nAccess detailed setup instructions, API config, platform connection guides, and workflow customization tips:\\n\\n📎 [Open the full documentation on Notion](https://automatisation.notion.site/NonoBanan-2643d6550fd98041aef5dcbe8ab0f7a1?source=copy_link)\\n\\n---\\n\\n# ⚙️ Requirements\\n\\n1. ✅ **Create a [Blotato](https://blotato.com/?ref=firas) account** (Pro plan required for API access)  \\n2. 🔑 **Generate your Blotato API Key** via: `Settings > API > Generate API Key`  \\n3. 📦 **Enable “Verified Community Nodes”** in the n8n admin settings  \\n4. 🧩 **Install the Blotato** verified community node in n8n  \\n5. 🛠 **Create a Blotato API credential** inside your n8n credentials tab  \\n6. 📄 **Duplicate this [Google Sheet template](https://docs.google.com/spreadsheets/d/1FutmZHblwnk36fp59fnePjONzuJBdndqZOCuRoGWSmY/edit?usp=sharing)**  \\n7. ☁️ **Make sure your Google Drive folder is PUBLIC** (anyone with the link can access)  \\n8. 📌 **Complete the 3 brown sticky note steps** inside the workflow editor\\n\\n","height":1476,"width":700,"color":6},"id":"77030cb3-3246-41d5-bcbc-74f82bdd501b","name":"Sticky Note5","type":"n8n-nodes-base.stickyNote","position":[368,240],"typeVersion":1}]	{"Merge":{"main":[[{"node":"Update Status to \\"DONE\\"","type":"main","index":0}]]},"Think":{"ai_tool":[[{"node":"AI Agent: Generate Video Script","type":"ai_tool","index":0}]]},"Tiktok":{"main":[[{"node":"Merge","type":"main","index":0}]]},"Bluesky":{"main":[[{"node":"Merge","type":"main","index":7}]]},"Threads":{"main":[[{"node":"Merge","type":"main","index":6}]]},"Youtube":{"main":[[{"node":"Merge","type":"main","index":5}]]},"Facebook":{"main":[[{"node":"Merge","type":"main","index":2}]]},"Linkedin":{"main":[[{"node":"Merge","type":"main","index":1}]]},"Instagram":{"main":[[{"node":"Merge","type":"main","index":3}]]},"Pinterest":{"main":[[{"node":"Merge","type":"main","index":8}]]},"Twitter (X)":{"main":[[{"node":"Merge","type":"main","index":4}]]},"Format Prompt":{"main":[[{"node":"Generate Video with VEO3","type":"main","index":0}]]},"LLM: OpenAI Chat":{"ai_languageModel":[[{"node":"Generate Image Prompt","type":"ai_languageModel","index":0}]]},"OpenAI Chat Model":{"ai_languageModel":[[{"node":"AI Agent: Generate Video Script","type":"ai_languageModel","index":0}]]},"Set Master Prompt":{"main":[[{"node":"AI Agent: Generate Video Script","type":"main","index":0}]]},"Wait for Image Edit":{"main":[[{"node":"Download Edited Image","type":"main","index":0}]]},"Download Edited Image":{"main":[[{"node":"Google Sheets: Read Video Parameters (CONFIG)","type":"main","index":0}]]},"Generate Image Prompt":{"main":[[{"node":"NanoBanana: Create Image","type":"main","index":0}]]},"Update Status to \\"DONE\\"":{"main":[[{"node":"Telegram: Send notification","type":"main","index":0}]]},"Upload Video to BLOTATO":{"main":[[{"node":"Tiktok","type":"main","index":0},{"node":"Linkedin","type":"main","index":0},{"node":"Facebook","type":"main","index":0},{"node":"Instagram","type":"main","index":0},{"node":"Twitter (X)","type":"main","index":0},{"node":"Youtube","type":"main","index":0},{"node":"Threads","type":"main","index":0},{"node":"Bluesky","type":"main","index":0},{"node":"Pinterest","type":"main","index":0}]]},"Wait for VEO3 Rendering":{"main":[[{"node":"Download Video from VEO3","type":"main","index":0}]]},"Download Video from VEO3":{"main":[[{"node":"Rewrite Caption with GPT-4o","type":"main","index":0}]]},"Generate Video with VEO3":{"main":[[{"node":"Wait for VEO3 Rendering","type":"main","index":0}]]},"NanoBanana: Create Image":{"main":[[{"node":"Wait for Image Edit","type":"main","index":0}]]},"Send Final Video Preview":{"main":[[{"node":"Upload Video to BLOTATO","type":"main","index":0}]]},"Structured Output Parser":{"ai_outputParser":[[{"node":"AI Agent: Generate Video Script","type":"ai_outputParser","index":0}]]},"Telegram: Get Image File":{"main":[[{"node":"Google Drive: Upload Image","type":"main","index":0}]]},"Google Drive: Upload Image":{"main":[[{"node":"Google Sheets: Log Image & Caption","type":"main","index":0}]]},"Telegram API: Get File URL":{"main":[[{"node":"OpenAI Vision: Analyze Reference Image","type":"main","index":0}]]},"Rewrite Caption with GPT-4o":{"main":[[{"node":"Save Caption Video to Google Sheets","type":"main","index":0}]]},"Send Video URL via Telegram":{"main":[[{"node":"Send Final Video Preview","type":"main","index":0}]]},"Set: Bot Token (Placeholder)":{"main":[[{"node":"Telegram API: Get File URL","type":"main","index":0}]]},"LLM: Structured Output Parser":{"ai_outputParser":[[{"node":"Generate Image Prompt","type":"ai_outputParser","index":0}]]},"AI Agent: Generate Video Script":{"main":[[{"node":"Format Prompt","type":"main","index":0}]]},"Google Sheets: Log Image & Caption":{"main":[[{"node":"Set: Bot Token (Placeholder)","type":"main","index":0}]]},"Save Caption Video to Google Sheets":{"main":[[{"node":"Send Video URL via Telegram","type":"main","index":0}]]},"Telegram Trigger: Receive Video Idea":{"main":[[{"node":"Set: Bot Token (Placeholder)","type":"main","index":0},{"node":"Telegram: Get Image File","type":"main","index":0}]]},"OpenAI Vision: Analyze Reference Image":{"main":[[{"node":"Google Sheets: Update Image Description","type":"main","index":0}]]},"Google Sheets: Update Image Description":{"main":[[{"node":"Generate Image Prompt","type":"main","index":0}]]},"Google Sheets: Read Video Parameters (CONFIG)":{"main":[[{"node":"Set Master Prompt","type":"main","index":0}]]}}	2026-04-28 11:34:29.429+00	2026-04-28 11:34:29.429+00	{"executionOrder":"v1","binaryMode":"separate"}	\N	{}	12c33da6-1b8f-4eb6-92ff-91244dc2e863	0	wg2lnJe3gmOxJddG	{"templateId":"8270"}	\N	f	1	\N	\N
My workflow	f	[{"parameters":{},"type":"n8n-nodes-base.manualTrigger","typeVersion":1,"position":[0,0],"id":"ff5a732c-7d53-443e-adf0-53e433fc7a50","name":"When clicking ‘Execute workflow’"},{"parameters":{"url":"http://host.docker.internal:8000/n8n-ping","options":{}},"type":"n8n-nodes-base.httpRequest","typeVersion":4.4,"position":[192,64],"id":"ae47912b-48d0-4628-80bb-e871690e57d9","name":"HTTP Request"}]	{"When clicking ‘Execute workflow’":{"main":[[{"node":"HTTP Request","type":"main","index":0}]]}}	2026-05-07 07:00:22.772+00	2026-05-07 07:00:48.529+00	{"executionOrder":"v1","binaryMode":"separate"}	\N	{}	785c1aca-de59-46db-a102-7e5a9a6fb0cc	0	CD2GddIS6pD1N23E	\N	\N	f	3	\N	\N
DevSignal — Main Pipeline	t	[{"parameters":{"rule":{"interval":[{"field":"hours","hoursInterval":12}]}},"id":"b38e6f47-0ed0-45d9-a630-e43103d9b9a4","name":"Every 12 Hours","type":"n8n-nodes-base.scheduleTrigger","typeVersion":1.2,"position":[-480,128]},{"parameters":{"method":"POST","url":"http://host.docker.internal:8000/run-pipeline","sendHeaders":true,"headerParameters":{"parameters":[{"name":"X-Api-Key","value":"devsignal-local-key-2024"}]},"options":{"response":{"response":{"fullResponse":true}},"timeout":4000000}},"id":"9616ca6d-5bb5-4253-a71f-8b0ce2579597","name":"Trigger Pipeline","type":"n8n-nodes-base.httpRequest","typeVersion":4.2,"position":[-240,128],"onError":"continueErrorOutput"},{"parameters":{"jsCode":"const response = $input.first().json;\\nconst body = response.body || response;\\nconsole.log('Pipeline status:', body.status);\\nconsole.log('Preview:', (body.preview || '').slice(-300));\\nreturn [{ json: { status: 'success', data: body } }];"},"id":"e8edd62b-4643-469c-9e33-08d99f49cbd6","name":"Log Success","type":"n8n-nodes-base.code","typeVersion":2,"position":[0,0]},{"parameters":{"jsCode":"const error = $input.first().json;\\nconst detail = error.error?.detail || error.message || 'Unknown error';\\nconst msg = typeof detail === 'object' ? JSON.stringify(detail) : String(detail);\\nconsole.error('Pipeline failed:', msg.slice(0, 500));\\nreturn [{ json: { status: 'failed', error_message: msg.slice(0, 1000) } }];"},"id":"c35065a3-6aa5-4045-be9b-09be07881794","name":"Parse Error","type":"n8n-nodes-base.code","typeVersion":2,"position":[0,240]},{"parameters":{"method":"POST","url":"=https://api.telegram.org/bot{{ $env.TELEGRAM_BOT_TOKEN }}/sendMessage","sendBody":true,"bodyParameters":{"parameters":[{}]},"options":{}},"id":"8e6ca49a-ea77-4b21-921b-c447b52a6954","name":"Telegram Error Alert","type":"n8n-nodes-base.httpRequest","typeVersion":4.2,"position":[240,240]}]	{"Every 12 Hours":{"main":[[{"node":"Trigger Pipeline","type":"main","index":0}]]},"Trigger Pipeline":{"main":[[{"node":"Log Success","type":"main","index":0}],[{"node":"Parse Error","type":"main","index":0}]]},"Parse Error":{"main":[[{"node":"Telegram Error Alert","type":"main","index":0}]]}}	2026-04-24 14:28:48.417+00	2026-05-06 15:40:46.09+00	{"executionOrder":"v1","binaryMode":"separate"}	{"node:Every 12 Hours":{"recurrenceRules":[2]}}	{}	c2fe07de-5bfc-470d-94ed-072de0da5de1	1	AlrynH2aZBv1h5NT	\N	\N	f	20	\N	c2fe07de-5bfc-470d-94ed-072de0da5de1
\.


--
-- Data for Name: workflow_history; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.workflow_history ("versionId", "workflowId", authors, "createdAt", "updatedAt", nodes, connections, name, autosaved, description) FROM stdin;
12c33da6-1b8f-4eb6-92ff-91244dc2e863	wg2lnJe3gmOxJddG	Sahan Maiti	2026-04-28 11:34:29.429+00	2026-04-28 11:34:29.429+00	[{"parameters":{"content":"# 📑 STEP 5 — Auto-Post to All Platforms\\n\\n","height":832,"width":1344,"color":4},"id":"101bdee1-4de4-4b5e-9170-4d490d4e8128","name":"Sticky Note3","type":"n8n-nodes-base.stickyNote","position":[2320,880],"typeVersion":1},{"parameters":{"mediaUrl":"={{ $('Download Video from VEO3').item.json.data.response.resultUrls[0] }}","resource":"media"},"id":"db2db976-7988-4939-a931-b6b2b98570aa","name":"Upload Video to BLOTATO","type":"@blotato/n8n-nodes-blotato.blotato","position":[2384,1504],"typeVersion":2,"credentials":{}},{"parameters":{"options":{},"platform":"youtube","accountId":{"__rl":true,"mode":"list","value":""},"postContentText":"={{ $('Save Caption Video to Google Sheets').item.json['CAPTION VIDEO'] }}","postContentMediaUrls":"={{ $json.url }}","postCreateYoutubeOptionTitle":"={{ $('Save Caption Video to Google Sheets').item.json['TITRE VIDEO'] }}","postCreateYoutubeOptionPrivacyStatus":"private","postCreateYoutubeOptionShouldNotifySubscribers":false},"id":"6866a654-e6a7-4543-b98a-8288f9d04b47","name":"Youtube","type":"@blotato/n8n-nodes-blotato.blotato","position":[3008,1296],"typeVersion":2,"credentials":{}},{"parameters":{"options":{},"platform":"tiktok","accountId":{"__rl":true,"mode":"list","value":""},"postContentText":"={{ $('Save Caption Video to Google Sheets').item.json['CAPTION VIDEO'] }}","postContentMediaUrls":"={{ $json.url }}"},"id":"a1b51932-2e2c-4e32-a37a-7ce94620cdd9","name":"Tiktok","type":"@blotato/n8n-nodes-blotato.blotato","position":[2640,1120],"typeVersion":2,"credentials":{}},{"parameters":{"mode":"chooseBranch","numberInputs":9},"id":"2c6cb6a6-e4b2-470d-8afb-b2c03b72e97b","name":"Merge","type":"n8n-nodes-base.merge","position":[3296,1200],"typeVersion":3.2},{"parameters":{"operation":"appendOrUpdate","documentId":{"__rl":true,"mode":"id","value":""},"sheetName":{"__rl":true,"mode":"id","value":""}},"id":"bee496d6-fc2d-4f1c-812f-9d6be08154a7","name":"Update Status to \\"DONE\\"","type":"n8n-nodes-base.googleSheets","position":[3472,1312],"typeVersion":4.5},{"parameters":{"options":{},"platform":"linkedin","accountId":{"__rl":true,"mode":"list","value":""},"postContentText":"={{ $('Save Caption Video to Google Sheets').item.json['CAPTION VIDEO'] }}","postContentMediaUrls":"={{ $json.url }}"},"id":"5f7344d8-a277-457b-a33f-c48e2ced1e49","name":"Linkedin","type":"@blotato/n8n-nodes-blotato.blotato","position":[2832,1120],"typeVersion":2,"credentials":{}},{"parameters":{"options":{},"platform":"facebook","accountId":{"__rl":true,"mode":"list","value":""},"facebookPageId":{"__rl":true,"mode":"list","value":""},"postContentText":"={{ $('Save Caption Video to Google Sheets').item.json['CAPTION VIDEO'] }}","postContentMediaUrls":"={{ $json.url }}"},"id":"31bc2347-2457-4fad-8436-09282df89609","name":"Facebook","type":"@blotato/n8n-nodes-blotato.blotato","position":[3008,1120],"typeVersion":2,"credentials":{}},{"parameters":{"options":{},"accountId":{"__rl":true,"mode":"list","value":""},"postContentText":"={{ $('Save Caption Video to Google Sheets').item.json['CAPTION VIDEO'] }}","postContentMediaUrls":"={{ $json.url }}"},"id":"06e29e46-c3ce-4c9e-825d-39df924a607d","name":"Instagram","type":"@blotato/n8n-nodes-blotato.blotato","position":[2640,1296],"typeVersion":2,"credentials":{}},{"parameters":{"options":{},"platform":"threads","accountId":{"__rl":true,"mode":"list","value":""},"postContentText":"={{ $('Save Caption Video to Google Sheets').item.json['CAPTION VIDEO'] }}","postContentMediaUrls":"={{ $json.url }}"},"id":"3f7560c8-3e4a-4d62-bf62-e8d543df8026","name":"Threads","type":"@blotato/n8n-nodes-blotato.blotato","position":[2640,1504],"typeVersion":2,"credentials":{}},{"parameters":{"options":{},"platform":"bluesky","accountId":{"__rl":true,"mode":"list","value":""},"postContentText":"={{ $('Save Caption Video to Google Sheets').item.json['CAPTION VIDEO'] }}","postContentMediaUrls":"={{ $json.url }}"},"id":"3e4b6251-7c56-40ca-8fb6-4b77c910a2e6","name":"Bluesky","type":"@blotato/n8n-nodes-blotato.blotato","position":[2832,1504],"typeVersion":2,"credentials":{}},{"parameters":{"options":{},"platform":"pinterest","accountId":{"__rl":true,"mode":"list","value":""},"postContentText":"={{ $('Save Caption Video to Google Sheets').item.json['CAPTION VIDEO'] }}","pinterestBoardId":{"__rl":true,"mode":"id","value":""},"postContentMediaUrls":"={{ $json.url }}"},"id":"61f5f513-b7ec-40ca-a4a1-1b897f092a04","name":"Pinterest","type":"@blotato/n8n-nodes-blotato.blotato","position":[3008,1504],"typeVersion":2,"credentials":{}},{"parameters":{"options":{},"platform":"twitter","accountId":{"__rl":true,"mode":"list","value":""},"postContentText":"={{ $('Save Caption Video to Google Sheets').item.json['CAPTION VIDEO'] }}","postContentMediaUrls":"={{ $json.url }}"},"id":"4fb185bf-f237-4b71-8557-178f15f0caec","name":"Twitter (X)","type":"@blotato/n8n-nodes-blotato.blotato","position":[2832,1296],"typeVersion":2,"credentials":{}},{"parameters":{"model":{"__rl":true,"mode":"list","value":""},"options":{}},"id":"cb9939c6-1c5c-448b-ab3a-a66d90767cf2","name":"OpenAI Chat Model","type":"@n8n/n8n-nodes-langchain.lmChatOpenAi","position":[1840,1216],"typeVersion":1.2},{"parameters":{},"id":"2c244851-7835-4f4a-8fe9-10a26acf6365","name":"Think","type":"@n8n/n8n-nodes-langchain.toolThink","position":[1984,1216],"typeVersion":1},{"parameters":{"jsonSchemaExample":"{\\n  \\"title\\": \\"string\\",\\n  \\"final_prompt\\": \\"string\\"\\n}\\n"},"id":"0695e935-93ac-48da-a893-1615ce22a6e7","name":"Structured Output Parser","type":"@n8n/n8n-nodes-langchain.outputParserStructured","position":[2128,1216],"typeVersion":1.3},{"parameters":{"chatId":"={{ $('Telegram Trigger: Receive Video Idea').item.json.message.chat.id }}","text":"=Url VIDEO : {{ $('Download Video from VEO3').item.json.data.response.resultUrls[0] }}","additionalFields":{}},"id":"ff995af1-503e-4356-8e67-6392b4629496","name":"Send Video URL via Telegram","type":"n8n-nodes-base.telegram","position":[2368,1008],"webhookId":"ea6e5974-1930-4b67-a51b-16249a9ed8bd","typeVersion":1.2},{"parameters":{"operation":"sendVideo","chatId":"={{ $json.result.chat.id }}","file":"={{ $('Save Caption Video to Google Sheets').item.json['URL VIDEO FINAL'] }}","additionalFields":{}},"id":"257eedc1-30c1-4e40-913b-24ceb018df28","name":"Send Final Video Preview","type":"n8n-nodes-base.telegram","position":[2384,1248],"webhookId":"443fd41d-a051-45bf-ad68-173197dba26b","typeVersion":1.2},{"parameters":{"updates":["message"],"additionalFields":{}},"id":"11f4ee14-912b-4a77-8696-7d36f7fc8a21","name":"Telegram Trigger: Receive Video Idea","type":"n8n-nodes-base.telegramTrigger","position":[1152,432],"webhookId":"26dbe6f5-5197-4b2b-9e32-8060f2119686","typeVersion":1.2},{"parameters":{"assignments":{"assignments":[{"id":"cc2e0500-57b1-4615-82cb-1c950e5f2ec4","name":"json_master","type":"string","value":"={\\n  \\"description\\": \\"Brief narrative description of the scene, focusing on key visual storytelling and product transformation.\\",\\n  \\"style\\": \\"cinematic | photorealistic | stylized | gritty | elegant\\",\\n  \\"camera\\": {\\n    \\"type\\": \\"fixed | dolly | Steadicam | crane combo\\",\\n    \\"movement\\": \\"describe any camera moves like slow push-in, pan, orbit\\",\\n    \\"lens\\": \\"optional lens type or focal length for cinematic effect\\"\\n  },\\n  \\"lighting\\": {\\n    \\"type\\": \\"natural | dramatic | high-contrast\\",\\n    \\"sources\\": \\"key lighting sources (sunset, halogen, ambient glow...)\\",\\n    \\"FX\\": \\"optional VFX elements like fog, reflections, flares\\"\\n  },\\n  \\"environment\\": {\\n    \\"location\\": \\"describe location or room (kitchen, desert, basketball court...)\\",\\n    \\"set_pieces\\": [\\n      \\"list of key background or prop elements\\",\\n      \\"e.g. hardwood floors, chain-link fence, velvet surface\\"\\n    ],\\n    \\"mood\\": \\"describe the ambient atmosphere (moody, clean, epic...)\\"\\n  },\\n  \\"elements\\": [\\n    \\"main physical items involved (product box, accessories, vehicles...)\\",\\n    \\"include brand visibility (logos, packaging, texture...)\\"\\n  ],\\n  \\"subject\\": {\\n    \\"character\\": {\\n      \\"description\\": \\"optional – physical description, outfit\\",\\n      \\"pose\\": \\"optional – position or gesture\\",\\n      \\"lip_sync_line\\": \\"optional – spoken line if there’s a voiceover\\"\\n    },\\n    \\"product\\": {\\n      \\"brand\\": \\"Brand name\\",\\n      \\"model\\": \\"Product model or name\\",\\n      \\"action\\": \\"description of product transformation or assembly\\"\\n    }\\n  },\\n  \\"motion\\": {\\n    \\"type\\": \\"e.g. transformation, explosion, vortex\\",\\n    \\"details\\": \\"step-by-step visual flow of how elements move or evolve\\"\\n  },\\n  \\"VFX\\": {\\n    \\"transformation\\": \\"optional – describe style (neon trails, motion blur...)\\",\\n    \\"impact\\": \\"optional – e.g. shockwave, glow, distortion\\",\\n    \\"particles\\": \\"optional – embers, sparks, thread strands...\\",\\n    \\"environment\\": \\"optional – VFX affecting the scene (ripples, wind...)\\"\\n  },\\n  \\"audio\\": {\\n    \\"music\\": \\"optional – cinematic score, trap beat, ambient tone\\",\\n    \\"sfx\\": [\\n      \\"list of sound effects (zip, pop, woosh...)\\"\\n    ],\\n    \\"ambience\\": \\"optional – background soundscape (traffic, wind...)\\",\\n    \\"voiceover\\": {\\n      \\"delivery\\": \\"tone and style (confident, whisper, deep...)\\",\\n      \\"line\\": \\"text spoken if applicable\\"\\n    }\\n  },\\n  \\"ending\\": \\"Final shot description – what is seen or felt at the end (freeze frame, logo pulse, glow...)\\",\\n  \\"text\\": \\"none | overlay | tagline | logo pulse at end only\\",\\n  \\"format\\": \\"16:9 | 4k | vertical\\",\\n  \\"keywords\\": [\\n    \\"brand\\",\\n    \\"scene style\\",\\n    \\"motion type\\",\\n    \\"camera style\\",\\n    \\"sound mood\\",\\n    \\"target theme\\"\\n  ]\\n}\\n"}]},"options":{}},"id":"45e0b8ee-b830-48bc-8a9a-a426a7afcd43","name":"Set Master Prompt","type":"n8n-nodes-base.set","position":[1600,992],"typeVersion":3.4},{"parameters":{"promptType":"define","text":"=Create a UGC-style video prompt using both the reference image and the user description.  \\n\\n**Inputs**  \\n- User description (optional):  \\n  `{{ $('Telegram Trigger: Receive Video Idea').item.json.message.caption }}`  \\n- Reference image analysis (stay strictly faithful to what’s visible):  \\n  `{{ $('Google Sheets: Update Image Description').item.json['IMAGE DESCRIPTION'] }}`  \\n\\n**Rules**  \\n- Keep the style casual, authentic, and realistic. Avoid studio-like or cinematic language.  \\n- Default model: `veo3_fast` (unless otherwise specified).  \\n- Output only **one JSON object** with the key: `video_prompt`.  \\n","hasOutputParser":true,"options":{"systemMessage":"=system_prompt:\\n  ## SYSTEM PROMPT: Structured Video Ad Prompt Generator\\n  A - Ask:\\n    Generate a structured video ad prompt for cinematic generation, strictly based on the master schema provided in: {{ $json.json_master }}.\\n    The final result must be a JSON object with exactly two top-level keys: `title` and `final_prompt`.\\n\\n  G - Guidance:\\n    role: Creative Director\\n    output_count: 1\\n    character_limit: None\\n    constraints:\\n      - The output must be valid JSON.\\n      - The `title` field should contain a short, descriptive and unique title (max 15 words).\\n      - The `final_prompt` field must contain a **single-line JSON string** that follows the exact structure of {{ $json.json_master }} with all fields preserved.\\n      - Do not include any explanations, markdown, or extra text — only the JSON object.\\n      - Escape all inner quotes in the `final_prompt` string so it is valid as a stringified JSON inside another JSON.\\n    tool_usage:\\n      - Ensure consistent alignment across all fields (camera, lighting, motion, etc.).\\n      - Maintain full structure even for optional fields (use \\"none\\", \\"\\", or [] as needed).\\n\\n  N - Notation:\\n    format: JSON\\n    expected_output:\\n      {\\n        \\"title\\": \\"A unique short title for the scene\\",\\n        \\"final_prompt\\": \\"{...stringified JSON of the full prompt...}\\"\\n      }\\n\\n"}},"id":"a27e8e28-cb43-4b3f-a96e-e986a25209fb","name":"AI Agent: Generate Video Script","type":"@n8n/n8n-nodes-langchain.agent","position":[1920,992],"typeVersion":2},{"parameters":{"method":"POST","url":"https://api.kie.ai/api/v1/veo/generate","authentication":"genericCredentialType","genericAuthType":"httpHeaderAuth","sendBody":true,"contentType":"raw","rawContentType":"application/json","body":"={\\n  \\"prompt\\": {{ $json.prompt }},\\n  \\"model\\": \\"{{ $('Google Sheets: Read Video Parameters (CONFIG)').item.json.model }}\\",\\n  \\"aspectRatio\\": \\"{{ $json.aspectRatio }}\\",\\n  \\"imageUrls\\": [\\n    \\"{{ $('Download Edited Image').item.json.images[0].url }}\\"\\n  ]\\n}","options":{}},"id":"16902ea9-197e-4cac-936e-83c1fc226854","name":"Generate Video with VEO3","type":"n8n-nodes-base.httpRequest","position":[1200,1504],"typeVersion":4.2},{"parameters":{"amount":20},"id":"a7fffb23-dba4-4d1e-a42e-191a1414ec60","name":"Wait for VEO3 Rendering","type":"n8n-nodes-base.wait","position":[1408,1504],"webhookId":"f6d814f3-4eb8-4629-a920-134cfa4ea03b","typeVersion":1.1},{"parameters":{"url":"https://api.kie.ai/api/v1/veo/record-info","authentication":"genericCredentialType","genericAuthType":"httpHeaderAuth","sendQuery":true,"queryParameters":{"parameters":[{"name":"taskId","value":"={{ $('Generate Video with VEO3').item.json.data.taskId }}"}]},"options":{}},"id":"67889216-2c0f-4ed8-ae54-8e7e7fdbac90","name":"Download Video from VEO3","type":"n8n-nodes-base.httpRequest","position":[1616,1504],"typeVersion":4.2},{"parameters":{"modelId":{"__rl":true,"mode":"list","value":""},"messages":{"values":[{"content":"=You are rewriting a TikTok video script, caption, and overlay —\\nnot inventing a new one. You must follow this format and obey\\nthese rules strictly.\\n---\\n### CONTEXT:\\nHere is the content idea to use:{{ $('Telegram Trigger: Receive Video Idea').item.json.message.caption }}\\n\\nand the Title is : {{ $('AI Agent: Generate Video Script').item.json.output.title }}\\n\\n\\nWrite the caption text using the topic.\\n\\n---\\n- MUST be under 200 characters (yes \\"Characters\\" not wordcount)\\nthis is an absolute MUST, no more than 200 characters!!! \\n\\n### FINAL OUTPUT FORMAT (no markdown formatting):\\n\\nDO NOT return any explanations. Only return the Caption Text\\n"}]},"options":{}},"id":"f6dda272-6129-4c04-b4c2-1e6bf5d156d8","name":"Rewrite Caption with GPT-4o","type":"@n8n/n8n-nodes-langchain.openAi","position":[1776,1504],"typeVersion":1.8},{"parameters":{"operation":"appendOrUpdate","documentId":{"__rl":true,"mode":"id","value":""},"sheetName":{"__rl":true,"mode":"id","value":""}},"id":"8b4c6b55-a0d7-4a19-b85c-1927ccb5eaa2","name":"Save Caption Video to Google Sheets","type":"n8n-nodes-base.googleSheets","position":[2080,1504],"typeVersion":4.6},{"parameters":{"jsCode":"const structuredPrompt = $input.first().json.output.final_prompt;\\nreturn {\\n  json: {\\n    prompt: JSON.stringify(structuredPrompt), // this escapes it correctly!\\n    model: \\"veo3_fast\\",\\n    aspectRatio: \\"16:9\\"\\n  }\\n};\\n"},"id":"30c415e0-58e0-48b9-b7e9-11dc5d979ac8","name":"Format Prompt","type":"n8n-nodes-base.code","position":[1200,1200],"typeVersion":2},{"parameters":{"content":"# 📑 STEP 3 — Generate Video Ad Script","height":460,"width":1180},"id":"61ce4a03-4104-4beb-bb16-0b2d2dde142d","name":"Sticky Note2","type":"n8n-nodes-base.stickyNote","position":[1088,880],"typeVersion":1},{"parameters":{"content":"# 📑 STEP 4 — Generate Video with VEO3","height":320,"width":1180},"id":"9f91c353-3ad6-498c-ba14-907bb91e208c","name":"Sticky Note4","type":"n8n-nodes-base.stickyNote","position":[1088,1392],"typeVersion":1},{"parameters":{"content":"# 📑 STEP 1 — Collect Idea & Image","height":592,"width":1184},"id":"3051b833-571a-4f0c-993a-ca8ffd03e476","name":"Sticky Note","type":"n8n-nodes-base.stickyNote","position":[1088,240],"typeVersion":1},{"parameters":{"content":"# 📑 STEP 2 — Create Image with NanoBanana\\n","height":592,"width":1328},"id":"785aa7c8-8921-4b6b-8db3-8d55e2a42564","name":"Sticky Note1","type":"n8n-nodes-base.stickyNote","position":[2320,240],"typeVersion":1},{"parameters":{"resource":"file","fileId":"={{ $json.message.photo[2].file_id }}","additionalFields":{}},"id":"fa25f6bf-d05b-4b8d-8a8a-b8684c601510","name":"Telegram: Get Image File","type":"n8n-nodes-base.telegram","position":[1584,304],"webhookId":"06ceb31d-dcd9-4a9a-bbbe-a7bf7ae0ad4a","typeVersion":1.2},{"parameters":{"name":"={{ $('Telegram Trigger: Receive Video Idea').item.json.message.photo[2].file_unique_id }}","driveId":{"__rl":true,"mode":"id","value":""},"folderId":{"__rl":true,"mode":"id","value":""},"options":{}},"id":"7a362123-c86c-45f9-b80c-a5660f92da46","name":"Google Drive: Upload Image","type":"n8n-nodes-base.googleDrive","position":[1600,496],"typeVersion":3},{"parameters":{"operation":"appendOrUpdate","documentId":{"__rl":true,"mode":"id","value":""},"sheetName":{"__rl":true,"mode":"id","value":""}},"id":"a9614733-44e3-4580-95f8-a955d9136be4","name":"Google Sheets: Log Image & Caption","type":"n8n-nodes-base.googleSheets","position":[1600,672],"typeVersion":4.7},{"parameters":{"assignments":{"assignments":[{"id":"af62651a-3fc8-419d-908b-6514f6f4bcb3","name":"YOUR_BOT_TOKEN","type":"string","value":""}]},"options":{}},"id":"a8e85901-2451-4037-ba0c-aa2b229c9d0f","name":"Set: Bot Token (Placeholder)","type":"n8n-nodes-base.set","position":[1840,432],"typeVersion":3.4},{"parameters":{"url":"=https://api.telegram.org/bot{{ $json.YOUR_BOT_TOKEN }}/getFile?file_id={{ $('Telegram Trigger: Receive Video Idea').item.json.message.photo[3].file_id }}","options":{}},"id":"ae9da8d7-f2c4-4ada-897c-651176cbfdb6","name":"Telegram API: Get File URL","type":"n8n-nodes-base.httpRequest","position":[2032,432],"typeVersion":4.2},{"parameters":{"resource":"image","operation":"analyze","modelId":{"__rl":true,"mode":"list","value":""},"text":"=You are an image analysis assistant.\\n\\nYour task is to analyze the given image and output results **only in YAML format**. Do not add explanations, comments, or extra text outside YAML.\\n\\nRules:\\n\\n- If the image depicts a **product**, return:\\n    \\n    ```yaml\\n    brand_name: (brand if visible or inferable)\\n    color_scheme:\\n      - hex: (hex code of each prominent color)\\n        name: (descriptive name of the color)\\n    font_style: (serif/sans-serif, bold/thin, etc.)\\n    visual_description: (1–2 sentences summarizing what is seen, ignoring the background)\\n    \\n    ```\\n    \\n- If the image depicts a **character**, return:\\n    \\n    ```yaml\\n    character_name: (name if visible or inferable, else \\"unknown\\")\\n    color_scheme:\\n      - hex: (hex code of each prominent color on the character)\\n        name: (descriptive name of the color)\\n    outfit_style: (clothing style, accessories, or notable features)\\n    visual_description: (1–2 sentences summarizing what the character looks like, ignoring the background)\\n    \\n    ```\\n    \\n- If the image depicts **both**, return **both sections** in YAML.\\n\\nOnly output valid YAML. No explanations.","imageUrls":"=https://api.telegram.org/file/bot{{ $('Set: Bot Token (Placeholder)').item.json.YOUR_BOT_TOKEN }}/{{ $json.result.file_path }}","options":{}},"id":"6527e03e-6417-45a5-95a8-2ef84b872df0","name":"OpenAI Vision: Analyze Reference Image","type":"@n8n/n8n-nodes-langchain.openAi","position":[2448,432],"typeVersion":1.8},{"parameters":{"operation":"appendOrUpdate","documentId":{"__rl":true,"mode":"id","value":""},"sheetName":{"__rl":true,"mode":"id","value":""}},"id":"6d78c44a-9073-4a2c-9a17-102c870b2162","name":"Google Sheets: Update Image Description","type":"n8n-nodes-base.googleSheets","position":[2688,432],"typeVersion":4.7},{"parameters":{"jsonSchemaExample":"{\\n\\t\\"image_prompt\\": \\"string\\"\\n}"},"id":"efd41bb8-ecef-49ea-9051-ead169d6766b","name":"LLM: Structured Output Parser","type":"@n8n/n8n-nodes-langchain.outputParserStructured","position":[3072,672],"typeVersion":1.3},{"parameters":{"model":{"__rl":true,"mode":"list","value":""},"options":{}},"id":"96a49fe4-d013-42c8-9ae8-11eb713e132f","name":"LLM: OpenAI Chat","type":"@n8n/n8n-nodes-langchain.lmChatOpenAi","position":[2864,672],"typeVersion":1.2},{"parameters":{"promptType":"define","text":"=Your task is to create an image prompt following the system guidelines.  \\nEnsure that the reference image is represented as **accurately as possible**, including all text elements.  \\n\\nUse the following inputs:  \\n\\n- **User’s description:**  \\n{{ $json.CAPTION }}\\n\\n- **Reference image description:**  \\n{{ $json['IMAGE DESCRIPTION'] }}\\n","hasOutputParser":true,"options":{"systemMessage":"=ROLE: UGC Image Prompt Builder  \\n\\nGOAL:  \\nGenerate one concise, natural, and realistic image prompt (≤120 words) from a given product or reference image. The prompt must simulate authentic UGC (user-generated content) photography.  \\n\\nRULES:  \\n- Always output **one JSON object only** with the key:  \\n  - `image_prompt`: (string with full description)  \\n- Do **not** add commentary, metadata, or extra keys. JSON only.  \\n\\nSTYLE GUIDELINES:  \\n- Tone: casual, unstaged, lifelike, handheld snapshot.  \\n- Camera cues: include at least 2–3 (e.g., phone snapshot, handheld framing, off-center composition, natural indoor light, soft shadows, slight motion blur, auto exposure, unpolished look, mild grain).  \\n- Realism: embrace imperfections (wrinkles, stray hairs, skin texture, clutter, smudges).  \\n- Packaging/Text: preserve exactly as visible. Never invent claims, numbers, or badges.  \\n- Diversity: if people appear but are unspecified, vary gender/ethnicity naturally; default age range = 21–38.  \\n- Setting: default to real-world everyday spaces (home, street, store, gym, office).  \\n\\nSAFETY:  \\n- No copyrighted character names.  \\n- No dialogue or scripts. Only describe scenes.  \\n\\nOUTPUT CONTRACT:  \\n- JSON only, no prose outside.  \\n- Max 120 words in `image_prompt`.  \\n- Must cover: subject, action, mood, setting, style/camera, colors, and text accuracy.  \\n\\nCHECKLIST BEFORE OUTPUT:  \\n- Natural handheld tone?  \\n- At least 2 camera cues included?  \\n- Product text preserved exactly?  \\n- Only JSON returned?  \\n\\n---  \\n\\n### Example  \\n\\nGood Example :  \\n```json\\n{ \\"image_prompt\\": \\"a young adult casually holding a skincare tube near a bathroom mirror; action: dabs small amount on the back of the hand; mood: easy morning; setting: small apartment bathroom with towel on rack and toothbrush cup; style/camera: phone snapshot, handheld framing, off-center composition, natural window light, slight motion blur, mild grain; colors: soft whites and mint label; text accuracy: keep every word on the tube exactly as visible, no added claims\\" }\\n"}},"id":"f6599d80-4301-4dd1-bc38-1c39e57e21cb","name":"Generate Image Prompt","type":"@n8n/n8n-nodes-langchain.agent","position":[2912,432],"typeVersion":2.2},{"parameters":{"method":"POST","url":"https://queue.fal.run/fal-ai/nano-banana/edit","authentication":"genericCredentialType","genericAuthType":"httpHeaderAuth","sendBody":true,"specifyBody":"json","jsonBody":"={\\n\\t\\"prompt\\": \\"{{ $json.output.image_prompt.replace(/\\\\\\"/g, '\\\\\\\\\\\\\\"').replace(/\\\\n/g, '\\\\\\\\n') }}\\",\\n\\"image_urls\\": [\\"{{ $('Google Drive: Upload Image').item.json.webContentLink }}\\"]\\n\\n}\\n\\n","options":{}},"id":"80274aa5-bdf0-49bf-9980-0624d99d68ef","name":"NanoBanana: Create Image","type":"n8n-nodes-base.httpRequest","position":[3248,432],"typeVersion":4.2},{"parameters":{"amount":20},"id":"e132487d-da8c-4850-9d3f-9e057e9bde64","name":"Wait for Image Edit","type":"n8n-nodes-base.wait","position":[3456,432],"webhookId":"df52d997-45c4-431f-bdf6-89dd25027b5b","typeVersion":1.1},{"parameters":{"url":"={{ $json.response_url }}","authentication":"genericCredentialType","genericAuthType":"httpHeaderAuth","options":{}},"id":"2c7ffce1-8ace-418d-9738-c659f4554980","name":"Download Edited Image","type":"n8n-nodes-base.httpRequest","position":[3456,656],"typeVersion":4.2},{"parameters":{"documentId":{"__rl":true,"mode":"id","value":""},"sheetName":{"__rl":true,"mode":"id","value":""}},"id":"ec725aa0-fd30-4d98-b984-0228873db428","name":"Google Sheets: Read Video Parameters (CONFIG)","type":"n8n-nodes-base.googleSheets","position":[1392,992],"typeVersion":4.6},{"parameters":{"chatId":"={{ $('Telegram Trigger: Receive Video Idea').item.json.message.chat.id }}","text":"Published","additionalFields":{}},"id":"abafa8c6-55a0-488c-970e-d2a969ad7959","name":"Telegram: Send notification","type":"n8n-nodes-base.telegram","position":[3472,1520],"webhookId":"2f4a4bc1-99de-4e93-8523-dd8c6499b893","typeVersion":1.2},{"parameters":{"content":"# 🎬 Generate AI viral videos with NanoBanana & VEO3, shared on socials via Blotato (By Dr. Firas)\\n\\n\\n# 🎥 Full Tutorial :\\n[![AI Voice Agent Preview](https://www.dr-firas.com/nanobanana.png)](https://youtu.be/nlwpbXQqNQ4)\\n\\n---\\n\\n# 📘 Documentation  \\nAccess detailed setup instructions, API config, platform connection guides, and workflow customization tips:\\n\\n📎 [Open the full documentation on Notion](https://automatisation.notion.site/NonoBanan-2643d6550fd98041aef5dcbe8ab0f7a1?source=copy_link)\\n\\n---\\n\\n# ⚙️ Requirements\\n\\n1. ✅ **Create a [Blotato](https://blotato.com/?ref=firas) account** (Pro plan required for API access)  \\n2. 🔑 **Generate your Blotato API Key** via: `Settings > API > Generate API Key`  \\n3. 📦 **Enable “Verified Community Nodes”** in the n8n admin settings  \\n4. 🧩 **Install the Blotato** verified community node in n8n  \\n5. 🛠 **Create a Blotato API credential** inside your n8n credentials tab  \\n6. 📄 **Duplicate this [Google Sheet template](https://docs.google.com/spreadsheets/d/1FutmZHblwnk36fp59fnePjONzuJBdndqZOCuRoGWSmY/edit?usp=sharing)**  \\n7. ☁️ **Make sure your Google Drive folder is PUBLIC** (anyone with the link can access)  \\n8. 📌 **Complete the 3 brown sticky note steps** inside the workflow editor\\n\\n","height":1476,"width":700,"color":6},"id":"77030cb3-3246-41d5-bcbc-74f82bdd501b","name":"Sticky Note5","type":"n8n-nodes-base.stickyNote","position":[368,240],"typeVersion":1}]	{"Merge":{"main":[[{"node":"Update Status to \\"DONE\\"","type":"main","index":0}]]},"Think":{"ai_tool":[[{"node":"AI Agent: Generate Video Script","type":"ai_tool","index":0}]]},"Tiktok":{"main":[[{"node":"Merge","type":"main","index":0}]]},"Bluesky":{"main":[[{"node":"Merge","type":"main","index":7}]]},"Threads":{"main":[[{"node":"Merge","type":"main","index":6}]]},"Youtube":{"main":[[{"node":"Merge","type":"main","index":5}]]},"Facebook":{"main":[[{"node":"Merge","type":"main","index":2}]]},"Linkedin":{"main":[[{"node":"Merge","type":"main","index":1}]]},"Instagram":{"main":[[{"node":"Merge","type":"main","index":3}]]},"Pinterest":{"main":[[{"node":"Merge","type":"main","index":8}]]},"Twitter (X)":{"main":[[{"node":"Merge","type":"main","index":4}]]},"Format Prompt":{"main":[[{"node":"Generate Video with VEO3","type":"main","index":0}]]},"LLM: OpenAI Chat":{"ai_languageModel":[[{"node":"Generate Image Prompt","type":"ai_languageModel","index":0}]]},"OpenAI Chat Model":{"ai_languageModel":[[{"node":"AI Agent: Generate Video Script","type":"ai_languageModel","index":0}]]},"Set Master Prompt":{"main":[[{"node":"AI Agent: Generate Video Script","type":"main","index":0}]]},"Wait for Image Edit":{"main":[[{"node":"Download Edited Image","type":"main","index":0}]]},"Download Edited Image":{"main":[[{"node":"Google Sheets: Read Video Parameters (CONFIG)","type":"main","index":0}]]},"Generate Image Prompt":{"main":[[{"node":"NanoBanana: Create Image","type":"main","index":0}]]},"Update Status to \\"DONE\\"":{"main":[[{"node":"Telegram: Send notification","type":"main","index":0}]]},"Upload Video to BLOTATO":{"main":[[{"node":"Tiktok","type":"main","index":0},{"node":"Linkedin","type":"main","index":0},{"node":"Facebook","type":"main","index":0},{"node":"Instagram","type":"main","index":0},{"node":"Twitter (X)","type":"main","index":0},{"node":"Youtube","type":"main","index":0},{"node":"Threads","type":"main","index":0},{"node":"Bluesky","type":"main","index":0},{"node":"Pinterest","type":"main","index":0}]]},"Wait for VEO3 Rendering":{"main":[[{"node":"Download Video from VEO3","type":"main","index":0}]]},"Download Video from VEO3":{"main":[[{"node":"Rewrite Caption with GPT-4o","type":"main","index":0}]]},"Generate Video with VEO3":{"main":[[{"node":"Wait for VEO3 Rendering","type":"main","index":0}]]},"NanoBanana: Create Image":{"main":[[{"node":"Wait for Image Edit","type":"main","index":0}]]},"Send Final Video Preview":{"main":[[{"node":"Upload Video to BLOTATO","type":"main","index":0}]]},"Structured Output Parser":{"ai_outputParser":[[{"node":"AI Agent: Generate Video Script","type":"ai_outputParser","index":0}]]},"Telegram: Get Image File":{"main":[[{"node":"Google Drive: Upload Image","type":"main","index":0}]]},"Google Drive: Upload Image":{"main":[[{"node":"Google Sheets: Log Image & Caption","type":"main","index":0}]]},"Telegram API: Get File URL":{"main":[[{"node":"OpenAI Vision: Analyze Reference Image","type":"main","index":0}]]},"Rewrite Caption with GPT-4o":{"main":[[{"node":"Save Caption Video to Google Sheets","type":"main","index":0}]]},"Send Video URL via Telegram":{"main":[[{"node":"Send Final Video Preview","type":"main","index":0}]]},"Set: Bot Token (Placeholder)":{"main":[[{"node":"Telegram API: Get File URL","type":"main","index":0}]]},"LLM: Structured Output Parser":{"ai_outputParser":[[{"node":"Generate Image Prompt","type":"ai_outputParser","index":0}]]},"AI Agent: Generate Video Script":{"main":[[{"node":"Format Prompt","type":"main","index":0}]]},"Google Sheets: Log Image & Caption":{"main":[[{"node":"Set: Bot Token (Placeholder)","type":"main","index":0}]]},"Save Caption Video to Google Sheets":{"main":[[{"node":"Send Video URL via Telegram","type":"main","index":0}]]},"Telegram Trigger: Receive Video Idea":{"main":[[{"node":"Set: Bot Token (Placeholder)","type":"main","index":0},{"node":"Telegram: Get Image File","type":"main","index":0}]]},"OpenAI Vision: Analyze Reference Image":{"main":[[{"node":"Google Sheets: Update Image Description","type":"main","index":0}]]},"Google Sheets: Update Image Description":{"main":[[{"node":"Generate Image Prompt","type":"main","index":0}]]},"Google Sheets: Read Video Parameters (CONFIG)":{"main":[[{"node":"Set Master Prompt","type":"main","index":0}]]}}	\N	t	\N
c2fe07de-5bfc-470d-94ed-072de0da5de1	AlrynH2aZBv1h5NT	Sahan Maiti	2026-05-05 07:59:13.767+00	2026-05-05 10:38:40.595+00	[{"parameters":{"rule":{"interval":[{"field":"hours","hoursInterval":12}]}},"id":"b38e6f47-0ed0-45d9-a630-e43103d9b9a4","name":"Every 12 Hours","type":"n8n-nodes-base.scheduleTrigger","typeVersion":1.2,"position":[-480,128]},{"parameters":{"method":"POST","url":"http://host.docker.internal:8000/run-pipeline","sendHeaders":true,"headerParameters":{"parameters":[{"name":"X-Api-Key","value":"devsignal-local-key-2024"}]},"options":{"response":{"response":{"fullResponse":true}},"timeout":4000000}},"id":"9616ca6d-5bb5-4253-a71f-8b0ce2579597","name":"Trigger Pipeline","type":"n8n-nodes-base.httpRequest","typeVersion":4.2,"position":[-240,128],"onError":"continueErrorOutput"},{"parameters":{"jsCode":"const response = $input.first().json;\\nconst body = response.body || response;\\nconsole.log('Pipeline status:', body.status);\\nconsole.log('Preview:', (body.preview || '').slice(-300));\\nreturn [{ json: { status: 'success', data: body } }];"},"id":"e8edd62b-4643-469c-9e33-08d99f49cbd6","name":"Log Success","type":"n8n-nodes-base.code","typeVersion":2,"position":[0,0]},{"parameters":{"jsCode":"const error = $input.first().json;\\nconst detail = error.error?.detail || error.message || 'Unknown error';\\nconst msg = typeof detail === 'object' ? JSON.stringify(detail) : String(detail);\\nconsole.error('Pipeline failed:', msg.slice(0, 500));\\nreturn [{ json: { status: 'failed', error_message: msg.slice(0, 1000) } }];"},"id":"c35065a3-6aa5-4045-be9b-09be07881794","name":"Parse Error","type":"n8n-nodes-base.code","typeVersion":2,"position":[0,240]},{"parameters":{"method":"POST","url":"=https://api.telegram.org/bot{{ $env.TELEGRAM_BOT_TOKEN }}/sendMessage","sendBody":true,"bodyParameters":{"parameters":[{}]},"options":{}},"id":"8e6ca49a-ea77-4b21-921b-c447b52a6954","name":"Telegram Error Alert","type":"n8n-nodes-base.httpRequest","typeVersion":4.2,"position":[240,240]}]	{"Every 12 Hours":{"main":[[{"node":"Trigger Pipeline","type":"main","index":0}]]},"Trigger Pipeline":{"main":[[{"node":"Log Success","type":"main","index":0}],[{"node":"Parse Error","type":"main","index":0}]]},"Parse Error":{"main":[[{"node":"Telegram Error Alert","type":"main","index":0}]]}}	Version c2fe07de	t	
785c1aca-de59-46db-a102-7e5a9a6fb0cc	CD2GddIS6pD1N23E	Sahan Maiti	2026-05-07 07:00:48.53+00	2026-05-07 07:00:48.53+00	[{"parameters":{},"type":"n8n-nodes-base.manualTrigger","typeVersion":1,"position":[0,0],"id":"ff5a732c-7d53-443e-adf0-53e433fc7a50","name":"When clicking ‘Execute workflow’"},{"parameters":{"url":"http://host.docker.internal:8000/n8n-ping","options":{}},"type":"n8n-nodes-base.httpRequest","typeVersion":4.4,"position":[192,64],"id":"ae47912b-48d0-4628-80bb-e871690e57d9","name":"HTTP Request"}]	{"When clicking ‘Execute workflow’":{"main":[[{"node":"HTTP Request","type":"main","index":0}]]}}	\N	t	\N
ac4286bc-4dba-4722-994b-0b58812c8d3f	irl7JgZwJOTujHbm	Sahan Maiti	2026-05-07 07:24:09.303+00	2026-05-07 07:24:09.303+00	[{"parameters":{"rule":{"interval":[{"field":"hours","hoursInterval":12}]}},"id":"a8d8e941-839c-4994-8e5d-590a17b21236","name":"Every 12 Hours","type":"n8n-nodes-base.scheduleTrigger","typeVersion":1.2,"position":[-480,112]},{"parameters":{"jsCode":"// Log success to console\\nconst output = $input.first().json;\\nconst stdout = output.stdout || '';\\nconsole.log('Pipeline completed successfully');\\nconsole.log('Output length:', stdout.length, 'chars');\\n\\n// Return summary\\nreturn [{\\n  json: {\\n    status: 'success',\\n    timestamp: new Date().toISOString(),\\n    output_preview: stdout.slice(-500)\\n  }\\n}];"},"id":"6cbb17c4-be30-4171-b346-ab37c0b0fee5","name":"Log Success","type":"n8n-nodes-base.code","typeVersion":2,"position":[0,0]},{"parameters":{"jsCode":"// Extract error info\\nconst errorData = $input.first().json;\\nconst stdout   = errorData.stdout || '';\\nconst stderr   = errorData.stderr || '';\\nconst exitCode = errorData.exitCode || 'unknown';\\n\\nconst errorMsg = stderr || stdout || 'Unknown error';\\n\\nconsole.error('Pipeline FAILED:', errorMsg.slice(0, 500));\\n\\nreturn [{\\n  json: {\\n    status:    'failed',\\n    exit_code: exitCode,\\n    error_msg: errorMsg.slice(0, 1000),\\n    timestamp: new Date().toISOString()\\n  }\\n}];"},"id":"443da55f-7aaf-4752-b084-2415fee40658","name":"Parse Error","type":"n8n-nodes-base.code","typeVersion":2,"position":[0,224]},{"parameters":{"method":"POST","url":"=https://api.telegram.org/bot{{ $env.TELEGRAM_BOT_TOKEN }}/sendMessage","sendBody":true,"bodyParameters":{"parameters":[{"name":"chat_id","value":"={{ $env.TELEGRAM_CHAT_ID }}"},{"name":"text","value":"=<b>DevSignal — Pipeline Failed</b>\\n\\nTime: {{ $json.timestamp }}\\nExit: {{ $json.exit_code }}\\n\\n<code>{{ $json.error_msg.slice(0, 500) }}</code>"},{"name":"parse_mode","value":"HTML"}]},"options":{}},"id":"7567a15f-1fa3-443b-aa40-ead578f52fe0","name":"Telegram Error Alert","type":"n8n-nodes-base.httpRequest","typeVersion":4.2,"position":[240,224]},{"parameters":{"command":"bash /app/run_pipeline.sh 2>&1"},"id":"02a864ff-c4ea-484f-a935-05dea56f2cfd","name":"Run Pipeline","type":"n8n-nodes-base.executeCommand","typeVersion":1,"position":[-208,96],"onError":"continueErrorOutput"}]	{"Parse Error":{"main":[[{"node":"Telegram Error Alert","type":"main","index":0}]]},"Every 12 Hours":{"main":[[]]},"Log Success":{"main":[[]]}}	\N	f	\N
\.


--
-- Data for Name: workflow_publish_history; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.workflow_publish_history (id, "workflowId", "versionId", event, "userId", "createdAt") FROM stdin;
3	AlrynH2aZBv1h5NT	c2fe07de-5bfc-470d-94ed-072de0da5de1	activated	53d71736-ba1a-44ab-ba08-8a9fbe5cee25	2026-05-05 10:38:40.587+00
\.


--
-- Data for Name: workflow_published_version; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.workflow_published_version ("workflowId", "publishedVersionId", "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: workflow_statistics; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.workflow_statistics (count, "latestEvent", name, "workflowId", "rootCount", id, "workflowName") FROM stdin;
1	2026-04-28 11:08:06.23+00	data_loaded	AlrynH2aZBv1h5NT	1	2	\N
2	2026-04-30 20:51:55.509+00	production_success	AlrynH2aZBv1h5NT	2	6	DevSignal — Main Pipeline
2	2026-05-05 07:37:44.63+00	manual_error	AlrynH2aZBv1h5NT	0	1	DevSignal — Main Pipeline
2	2026-05-07 07:01:30.823+00	manual_error	CD2GddIS6pD1N23E	0	18	My workflow
1	2026-05-07 07:23:01.792+00	data_loaded	CD2GddIS6pD1N23E	1	20	\N
1	2026-05-07 07:23:01.802+00	manual_success	CD2GddIS6pD1N23E	0	21	My workflow
15	2026-05-07 10:49:31.644+00	manual_success	AlrynH2aZBv1h5NT	0	3	DevSignal — Main Pipeline
\.


--
-- Data for Name: workflows_tags; Type: TABLE DATA; Schema: public; Owner: radar
--

COPY public.workflows_tags ("workflowId", "tagId") FROM stdin;
\.


--
-- Name: auth_provider_sync_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: radar
--

SELECT pg_catalog.setval('public.auth_provider_sync_history_id_seq', 1, false);


--
-- Name: companies_watchlist_id_seq; Type: SEQUENCE SET; Schema: public; Owner: radar
--

SELECT pg_catalog.setval('public.companies_watchlist_id_seq', 4, true);


--
-- Name: credential_dependency_id_seq; Type: SEQUENCE SET; Schema: public; Owner: radar
--

SELECT pg_catalog.setval('public.credential_dependency_id_seq', 1, false);


--
-- Name: device_tokens_id_seq; Type: SEQUENCE SET; Schema: public; Owner: radar
--

SELECT pg_catalog.setval('public.device_tokens_id_seq', 1, false);


--
-- Name: execution_annotations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: radar
--

SELECT pg_catalog.setval('public.execution_annotations_id_seq', 1, false);


--
-- Name: execution_entity_id_seq; Type: SEQUENCE SET; Schema: public; Owner: radar
--

SELECT pg_catalog.setval('public.execution_entity_id_seq', 22, true);


--
-- Name: execution_metadata_temp_id_seq; Type: SEQUENCE SET; Schema: public; Owner: radar
--

SELECT pg_catalog.setval('public.execution_metadata_temp_id_seq', 1, false);


--
-- Name: insights_by_period_id_seq; Type: SEQUENCE SET; Schema: public; Owner: radar
--

SELECT pg_catalog.setval('public.insights_by_period_id_seq', 6, true);


--
-- Name: insights_metadata_metaId_seq; Type: SEQUENCE SET; Schema: public; Owner: radar
--

SELECT pg_catalog.setval('public."insights_metadata_metaId_seq"', 2, true);


--
-- Name: insights_raw_id_seq; Type: SEQUENCE SET; Schema: public; Owner: radar
--

SELECT pg_catalog.setval('public.insights_raw_id_seq', 6, true);


--
-- Name: instance_version_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: radar
--

SELECT pg_catalog.setval('public.instance_version_history_id_seq', 1, false);


--
-- Name: migrations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: radar
--

SELECT pg_catalog.setval('public.migrations_id_seq', 160, true);


--
-- Name: oauth_user_consents_id_seq; Type: SEQUENCE SET; Schema: public; Owner: radar
--

SELECT pg_catalog.setval('public.oauth_user_consents_id_seq', 1, false);


--
-- Name: opportunities_id_seq; Type: SEQUENCE SET; Schema: public; Owner: radar
--

SELECT pg_catalog.setval('public.opportunities_id_seq', 375, true);


--
-- Name: scrape_runs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: radar
--

SELECT pg_catalog.setval('public.scrape_runs_id_seq', 33, true);


--
-- Name: secrets_provider_connection_id_seq; Type: SEQUENCE SET; Schema: public; Owner: radar
--

SELECT pg_catalog.setval('public.secrets_provider_connection_id_seq', 1, false);


--
-- Name: workflow_dependency_id_seq; Type: SEQUENCE SET; Schema: public; Owner: radar
--

SELECT pg_catalog.setval('public.workflow_dependency_id_seq', 236, true);


--
-- Name: workflow_publish_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: radar
--

SELECT pg_catalog.setval('public.workflow_publish_history_id_seq', 3, true);


--
-- Name: workflow_statistics_id_seq; Type: SEQUENCE SET; Schema: public; Owner: radar
--

SELECT pg_catalog.setval('public.workflow_statistics_id_seq', 24, true);


--
-- Name: test_run PK_011c050f566e9db509a0fadb9b9; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.test_run
    ADD CONSTRAINT "PK_011c050f566e9db509a0fadb9b9" PRIMARY KEY (id);


--
-- Name: project_secrets_provider_access PK_0402b7fcec5415246656f102f83; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.project_secrets_provider_access
    ADD CONSTRAINT "PK_0402b7fcec5415246656f102f83" PRIMARY KEY ("secretsProviderConnectionId", "projectId");


--
-- Name: installed_packages PK_08cc9197c39b028c1e9beca225940576fd1a5804; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.installed_packages
    ADD CONSTRAINT "PK_08cc9197c39b028c1e9beca225940576fd1a5804" PRIMARY KEY ("packageName");


--
-- Name: instance_ai_run_snapshots PK_0a5fc9690a84950ebf1416fb146; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.instance_ai_run_snapshots
    ADD CONSTRAINT "PK_0a5fc9690a84950ebf1416fb146" PRIMARY KEY ("threadId", "runId");


--
-- Name: instance_ai_messages PK_156c6f287225e9befe0181bb02b; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.instance_ai_messages
    ADD CONSTRAINT "PK_156c6f287225e9befe0181bb02b" PRIMARY KEY (id);


--
-- Name: execution_metadata PK_17a0b6284f8d626aae88e1c16e4; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.execution_metadata
    ADD CONSTRAINT "PK_17a0b6284f8d626aae88e1c16e4" PRIMARY KEY (id);


--
-- Name: role_mapping_rule_project PK_198c5b5aea509d139274efcaf9a; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.role_mapping_rule_project
    ADD CONSTRAINT "PK_198c5b5aea509d139274efcaf9a" PRIMARY KEY ("roleMappingRuleId", "projectId");


--
-- Name: project_relation PK_1caaa312a5d7184a003be0f0cb6; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.project_relation
    ADD CONSTRAINT "PK_1caaa312a5d7184a003be0f0cb6" PRIMARY KEY ("projectId", "userId");


--
-- Name: chat_hub_sessions PK_1eafef1273c70e4464fec703412; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.chat_hub_sessions
    ADD CONSTRAINT "PK_1eafef1273c70e4464fec703412" PRIMARY KEY (id);


--
-- Name: instance_ai_iteration_logs PK_21c2b214b44bc6c34a6d3551c90; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.instance_ai_iteration_logs
    ADD CONSTRAINT "PK_21c2b214b44bc6c34a6d3551c90" PRIMARY KEY (id);


--
-- Name: folder_tag PK_27e4e00852f6b06a925a4d83a3e; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.folder_tag
    ADD CONSTRAINT "PK_27e4e00852f6b06a925a4d83a3e" PRIMARY KEY ("folderId", "tagId");


--
-- Name: instance_ai_threads PK_35575100e45cdedeb89ae0643e9; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.instance_ai_threads
    ADD CONSTRAINT "PK_35575100e45cdedeb89ae0643e9" PRIMARY KEY (id);


--
-- Name: role PK_35c9b140caaf6da09cfabb0d675; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.role
    ADD CONSTRAINT "PK_35c9b140caaf6da09cfabb0d675" PRIMARY KEY (slug);


--
-- Name: secrets_provider_connection PK_4350ae85e76f9ba7df1370acb5d; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.secrets_provider_connection
    ADD CONSTRAINT "PK_4350ae85e76f9ba7df1370acb5d" PRIMARY KEY (id);


--
-- Name: instance_ai_resources PK_45b5b0b6f715dae4292b86603d8; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.instance_ai_resources
    ADD CONSTRAINT "PK_45b5b0b6f715dae4292b86603d8" PRIMARY KEY (id);


--
-- Name: project PK_4d68b1358bb5b766d3e78f32f57; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.project
    ADD CONSTRAINT "PK_4d68b1358bb5b766d3e78f32f57" PRIMARY KEY (id);


--
-- Name: dynamic_credential_entry PK_5135ffcabecad4727ff6b9b803d; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.dynamic_credential_entry
    ADD CONSTRAINT "PK_5135ffcabecad4727ff6b9b803d" PRIMARY KEY (credential_id, subject_id, resolver_id);


--
-- Name: workflow_dependency PK_52325e34cd7a2f0f67b0f3cad65; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.workflow_dependency
    ADD CONSTRAINT "PK_52325e34cd7a2f0f67b0f3cad65" PRIMARY KEY (id);


--
-- Name: invalid_auth_token PK_5779069b7235b256d91f7af1a15; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.invalid_auth_token
    ADD CONSTRAINT "PK_5779069b7235b256d91f7af1a15" PRIMARY KEY (token);


--
-- Name: shared_workflow PK_5ba87620386b847201c9531c58f; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.shared_workflow
    ADD CONSTRAINT "PK_5ba87620386b847201c9531c58f" PRIMARY KEY ("workflowId", "projectId");


--
-- Name: workflow_published_version PK_5c76fb7ee939fe2530374d3f75a; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.workflow_published_version
    ADD CONSTRAINT "PK_5c76fb7ee939fe2530374d3f75a" PRIMARY KEY ("workflowId");


--
-- Name: folder PK_6278a41a706740c94c02e288df8; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.folder
    ADD CONSTRAINT "PK_6278a41a706740c94c02e288df8" PRIMARY KEY (id);


--
-- Name: data_table_column PK_673cb121ee4a8a5e27850c72c51; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.data_table_column
    ADD CONSTRAINT "PK_673cb121ee4a8a5e27850c72c51" PRIMARY KEY (id);


--
-- Name: chat_hub_tools PK_696d26426c704fba79b2c195ef5; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.chat_hub_tools
    ADD CONSTRAINT "PK_696d26426c704fba79b2c195ef5" PRIMARY KEY (id);


--
-- Name: annotation_tag_entity PK_69dfa041592c30bbc0d4b84aa00; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.annotation_tag_entity
    ADD CONSTRAINT "PK_69dfa041592c30bbc0d4b84aa00" PRIMARY KEY (id);


--
-- Name: instance_ai_observational_memory PK_7192dd00cddba039bf1d3e6a098; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.instance_ai_observational_memory
    ADD CONSTRAINT "PK_7192dd00cddba039bf1d3e6a098" PRIMARY KEY (id);


--
-- Name: oauth_refresh_tokens PK_74abaed0b30711b6532598b0392; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.oauth_refresh_tokens
    ADD CONSTRAINT "PK_74abaed0b30711b6532598b0392" PRIMARY KEY (token);


--
-- Name: dynamic_credential_user_entry PK_74f548e633abc66dc27c8f0ca77; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.dynamic_credential_user_entry
    ADD CONSTRAINT "PK_74f548e633abc66dc27c8f0ca77" PRIMARY KEY ("credentialId", "userId", "resolverId");


--
-- Name: chat_hub_messages PK_7704a5add6baed43eef835f0bfb; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "PK_7704a5add6baed43eef835f0bfb" PRIMARY KEY (id);


--
-- Name: execution_annotations PK_7afcf93ffa20c4252869a7c6a23; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.execution_annotations
    ADD CONSTRAINT "PK_7afcf93ffa20c4252869a7c6a23" PRIMARY KEY (id);


--
-- Name: credential_dependency PK_80212729ed0ffa0709417ab28f4; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.credential_dependency
    ADD CONSTRAINT "PK_80212729ed0ffa0709417ab28f4" PRIMARY KEY (id);


--
-- Name: oauth_user_consents PK_85b9ada746802c8993103470f05; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.oauth_user_consents
    ADD CONSTRAINT "PK_85b9ada746802c8993103470f05" PRIMARY KEY (id);


--
-- Name: instance_version_history PK_874f58cb616935bf49d9dbd67e9; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.instance_version_history
    ADD CONSTRAINT "PK_874f58cb616935bf49d9dbd67e9" PRIMARY KEY (id);


--
-- Name: chat_hub_session_tools PK_87aea76ff4c274c4a5ac838ebe3; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.chat_hub_session_tools
    ADD CONSTRAINT "PK_87aea76ff4c274c4a5ac838ebe3" PRIMARY KEY ("sessionId", "toolId");


--
-- Name: migrations PK_8c82d7f526340ab734260ea46be; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.migrations
    ADD CONSTRAINT "PK_8c82d7f526340ab734260ea46be" PRIMARY KEY (id);


--
-- Name: installed_nodes PK_8ebd28194e4f792f96b5933423fc439df97d9689; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.installed_nodes
    ADD CONSTRAINT "PK_8ebd28194e4f792f96b5933423fc439df97d9689" PRIMARY KEY (name);


--
-- Name: shared_credentials PK_8ef3a59796a228913f251779cff; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.shared_credentials
    ADD CONSTRAINT "PK_8ef3a59796a228913f251779cff" PRIMARY KEY ("credentialsId", "projectId");


--
-- Name: test_case_execution PK_90c121f77a78a6580e94b794bce; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.test_case_execution
    ADD CONSTRAINT "PK_90c121f77a78a6580e94b794bce" PRIMARY KEY (id);


--
-- Name: instance_ai_workflow_snapshots PK_93f2696eb321dfe1d7defe7073f; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.instance_ai_workflow_snapshots
    ADD CONSTRAINT "PK_93f2696eb321dfe1d7defe7073f" PRIMARY KEY ("runId", "workflowName");


--
-- Name: user_api_keys PK_978fa5caa3468f463dac9d92e69; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.user_api_keys
    ADD CONSTRAINT "PK_978fa5caa3468f463dac9d92e69" PRIMARY KEY (id);


--
-- Name: execution_annotation_tags PK_979ec03d31294cca484be65d11f; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.execution_annotation_tags
    ADD CONSTRAINT "PK_979ec03d31294cca484be65d11f" PRIMARY KEY ("annotationId", "tagId");


--
-- Name: webhook_entity PK_b21ace2e13596ccd87dc9bf4ea6; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.webhook_entity
    ADD CONSTRAINT "PK_b21ace2e13596ccd87dc9bf4ea6" PRIMARY KEY ("webhookPath", method);


--
-- Name: insights_by_period PK_b606942249b90cc39b0265f0575; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.insights_by_period
    ADD CONSTRAINT "PK_b606942249b90cc39b0265f0575" PRIMARY KEY (id);


--
-- Name: workflow_history PK_b6572dd6173e4cd06fe79937b58; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.workflow_history
    ADD CONSTRAINT "PK_b6572dd6173e4cd06fe79937b58" PRIMARY KEY ("versionId");


--
-- Name: dynamic_credential_resolver PK_b76cfb088dcdaf5275e9980bb64; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.dynamic_credential_resolver
    ADD CONSTRAINT "PK_b76cfb088dcdaf5275e9980bb64" PRIMARY KEY (id);


--
-- Name: scope PK_bfc45df0481abd7f355d6187da1; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.scope
    ADD CONSTRAINT "PK_bfc45df0481abd7f355d6187da1" PRIMARY KEY (slug);


--
-- Name: oauth_clients PK_c4759172d3431bae6f04e678e0d; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.oauth_clients
    ADD CONSTRAINT "PK_c4759172d3431bae6f04e678e0d" PRIMARY KEY (id);


--
-- Name: workflow_publish_history PK_c788f7caf88e91e365c97d6d04a; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.workflow_publish_history
    ADD CONSTRAINT "PK_c788f7caf88e91e365c97d6d04a" PRIMARY KEY (id);


--
-- Name: processed_data PK_ca04b9d8dc72de268fe07a65773; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.processed_data
    ADD CONSTRAINT "PK_ca04b9d8dc72de268fe07a65773" PRIMARY KEY ("workflowId", context);


--
-- Name: chat_hub_agent_tools PK_cc8806fdea48297a7d497035d72; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.chat_hub_agent_tools
    ADD CONSTRAINT "PK_cc8806fdea48297a7d497035d72" PRIMARY KEY ("agentId", "toolId");


--
-- Name: role_mapping_rule PK_d772c8ec1a89b52d31c882bc560; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.role_mapping_rule
    ADD CONSTRAINT "PK_d772c8ec1a89b52d31c882bc560" PRIMARY KEY (id);


--
-- Name: token_exchange_jti PK_d8e8a6f737d530fdd2dd716e89c; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.token_exchange_jti
    ADD CONSTRAINT "PK_d8e8a6f737d530fdd2dd716e89c" PRIMARY KEY (jti);


--
-- Name: settings PK_dc0fe14e6d9943f268e7b119f69ab8bd; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.settings
    ADD CONSTRAINT "PK_dc0fe14e6d9943f268e7b119f69ab8bd" PRIMARY KEY (key);


--
-- Name: oauth_access_tokens PK_dcd71f96a5d5f4bf79e67d322bf; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.oauth_access_tokens
    ADD CONSTRAINT "PK_dcd71f96a5d5f4bf79e67d322bf" PRIMARY KEY (token);


--
-- Name: data_table PK_e226d0001b9e6097cbfe70617cb; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.data_table
    ADD CONSTRAINT "PK_e226d0001b9e6097cbfe70617cb" PRIMARY KEY (id);


--
-- Name: workflow_builder_session PK_e69ef0d385986e273423b0e8695; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.workflow_builder_session
    ADD CONSTRAINT "PK_e69ef0d385986e273423b0e8695" PRIMARY KEY (id);


--
-- Name: user PK_ea8f538c94b6e352418254ed6474a81f; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public."user"
    ADD CONSTRAINT "PK_ea8f538c94b6e352418254ed6474a81f" PRIMARY KEY (id);


--
-- Name: insights_raw PK_ec15125755151e3a7e00e00014f; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.insights_raw
    ADD CONSTRAINT "PK_ec15125755151e3a7e00e00014f" PRIMARY KEY (id);


--
-- Name: chat_hub_agents PK_f39a3b36bbdf0e2979ddb21cf78; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.chat_hub_agents
    ADD CONSTRAINT "PK_f39a3b36bbdf0e2979ddb21cf78" PRIMARY KEY (id);


--
-- Name: insights_metadata PK_f448a94c35218b6208ce20cf5a1; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.insights_metadata
    ADD CONSTRAINT "PK_f448a94c35218b6208ce20cf5a1" PRIMARY KEY ("metaId");


--
-- Name: oauth_authorization_codes PK_fb91ab932cfbd694061501cc20f; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.oauth_authorization_codes
    ADD CONSTRAINT "PK_fb91ab932cfbd694061501cc20f" PRIMARY KEY (code);


--
-- Name: binary_data PK_fc3691585b39408bb0551122af6; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.binary_data
    ADD CONSTRAINT "PK_fc3691585b39408bb0551122af6" PRIMARY KEY ("fileId");


--
-- Name: role_scope PK_role_scope; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.role_scope
    ADD CONSTRAINT "PK_role_scope" PRIMARY KEY ("roleSlug", "scopeSlug");


--
-- Name: oauth_user_consents UQ_083721d99ce8db4033e2958ebb4; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.oauth_user_consents
    ADD CONSTRAINT "UQ_083721d99ce8db4033e2958ebb4" UNIQUE ("userId", "clientId");


--
-- Name: data_table_column UQ_8082ec4890f892f0bc77473a123; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.data_table_column
    ADD CONSTRAINT "UQ_8082ec4890f892f0bc77473a123" UNIQUE ("dataTableId", name);


--
-- Name: data_table UQ_b23096ef747281ac944d28e8b0d; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.data_table
    ADD CONSTRAINT "UQ_b23096ef747281ac944d28e8b0d" UNIQUE ("projectId", name);


--
-- Name: role_mapping_rule UQ_b33ac896ad3099fc8de36fdc1c4; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.role_mapping_rule
    ADD CONSTRAINT "UQ_b33ac896ad3099fc8de36fdc1c4" UNIQUE (type, "order");


--
-- Name: user UQ_e12875dfb3b1d92d7d7c5377e2; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public."user"
    ADD CONSTRAINT "UQ_e12875dfb3b1d92d7d7c5377e2" UNIQUE (email);


--
-- Name: workflow_builder_session UQ_ec2aa73632932d485a1d5192ce1; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.workflow_builder_session
    ADD CONSTRAINT "UQ_ec2aa73632932d485a1d5192ce1" UNIQUE ("workflowId", "userId");


--
-- Name: applications applications_job_id_key; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_job_id_key UNIQUE (job_id);


--
-- Name: applications applications_pkey; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_pkey PRIMARY KEY (id);


--
-- Name: auth_identity auth_identity_pkey; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.auth_identity
    ADD CONSTRAINT auth_identity_pkey PRIMARY KEY ("providerId", "providerType");


--
-- Name: auth_provider_sync_history auth_provider_sync_history_pkey; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.auth_provider_sync_history
    ADD CONSTRAINT auth_provider_sync_history_pkey PRIMARY KEY (id);


--
-- Name: companies_watchlist companies_watchlist_company_key; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.companies_watchlist
    ADD CONSTRAINT companies_watchlist_company_key UNIQUE (company);


--
-- Name: companies_watchlist companies_watchlist_pkey; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.companies_watchlist
    ADD CONSTRAINT companies_watchlist_pkey PRIMARY KEY (id);


--
-- Name: credentials_entity credentials_entity_pkey; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.credentials_entity
    ADD CONSTRAINT credentials_entity_pkey PRIMARY KEY (id);


--
-- Name: device_tokens device_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.device_tokens
    ADD CONSTRAINT device_tokens_pkey PRIMARY KEY (id);


--
-- Name: device_tokens device_tokens_token_key; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.device_tokens
    ADD CONSTRAINT device_tokens_token_key UNIQUE (token);


--
-- Name: event_destinations event_destinations_pkey; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.event_destinations
    ADD CONSTRAINT event_destinations_pkey PRIMARY KEY (id);


--
-- Name: execution_data execution_data_pkey; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.execution_data
    ADD CONSTRAINT execution_data_pkey PRIMARY KEY ("executionId");


--
-- Name: opportunities opportunities_job_hash_key; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.opportunities
    ADD CONSTRAINT opportunities_job_hash_key UNIQUE (job_hash);


--
-- Name: opportunities opportunities_pkey; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.opportunities
    ADD CONSTRAINT opportunities_pkey PRIMARY KEY (id);


--
-- Name: execution_entity pk_e3e63bbf986767844bbe1166d4e; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.execution_entity
    ADD CONSTRAINT pk_e3e63bbf986767844bbe1166d4e PRIMARY KEY (id);


--
-- Name: workflows_tags pk_workflows_tags; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.workflows_tags
    ADD CONSTRAINT pk_workflows_tags PRIMARY KEY ("workflowId", "tagId");


--
-- Name: scrape_runs scrape_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.scrape_runs
    ADD CONSTRAINT scrape_runs_pkey PRIMARY KEY (id);


--
-- Name: tag_entity tag_entity_pkey; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.tag_entity
    ADD CONSTRAINT tag_entity_pkey PRIMARY KEY (id);


--
-- Name: variables variables_pkey; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.variables
    ADD CONSTRAINT variables_pkey PRIMARY KEY (id);


--
-- Name: workflow_entity workflow_entity_pkey; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.workflow_entity
    ADD CONSTRAINT workflow_entity_pkey PRIMARY KEY (id);


--
-- Name: workflow_statistics workflow_statistics_pkey; Type: CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.workflow_statistics
    ADD CONSTRAINT workflow_statistics_pkey PRIMARY KEY (id);


--
-- Name: IDX_02751202c9a2ad75f2d8e14f5e; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_02751202c9a2ad75f2d8e14f5e" ON public.instance_ai_iteration_logs USING btree ("threadId", "taskKey", "createdAt");


--
-- Name: IDX_070b5de842ece9ccdda0d9738b; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_070b5de842ece9ccdda0d9738b" ON public.workflow_publish_history USING btree ("workflowId", "versionId");


--
-- Name: IDX_14f68deffaf858465715995508; Type: INDEX; Schema: public; Owner: radar
--

CREATE UNIQUE INDEX "IDX_14f68deffaf858465715995508" ON public.folder USING btree ("projectId", id);


--
-- Name: IDX_1d8ab99d5861c9388d2dc1cf73; Type: INDEX; Schema: public; Owner: radar
--

CREATE UNIQUE INDEX "IDX_1d8ab99d5861c9388d2dc1cf73" ON public.insights_metadata USING btree ("workflowId");


--
-- Name: IDX_1e31657f5fe46816c34be7c1b4; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_1e31657f5fe46816c34be7c1b4" ON public.workflow_history USING btree ("workflowId");


--
-- Name: IDX_1eeb64cb9d66a927988de759e6; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_1eeb64cb9d66a927988de759e6" ON public.instance_ai_messages USING btree ("threadId");


--
-- Name: IDX_1ef35bac35d20bdae979d917a3; Type: INDEX; Schema: public; Owner: radar
--

CREATE UNIQUE INDEX "IDX_1ef35bac35d20bdae979d917a3" ON public.user_api_keys USING btree ("apiKey");


--
-- Name: IDX_35a78869286c65d9330d02b88f; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_35a78869286c65d9330d02b88f" ON public.role_mapping_rule_project USING btree ("projectId");


--
-- Name: IDX_4c72ebdb265d1775bf61147af0; Type: INDEX; Schema: public; Owner: radar
--

CREATE UNIQUE INDEX "IDX_4c72ebdb265d1775bf61147af0" ON public.chat_hub_tools USING btree ("ownerId", name);


--
-- Name: IDX_56900edc3cfd16612e2ef2c6a8; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_56900edc3cfd16612e2ef2c6a8" ON public.binary_data USING btree ("sourceType", "sourceId");


--
-- Name: IDX_5ec8e8c8d3539f3696cf73b43b; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_5ec8e8c8d3539f3696cf73b43b" ON public.credential_dependency USING btree ("credentialId");


--
-- Name: IDX_5f0643f6717905a05164090dde; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_5f0643f6717905a05164090dde" ON public.project_relation USING btree ("userId");


--
-- Name: IDX_60b6a84299eeb3f671dfec7693; Type: INDEX; Schema: public; Owner: radar
--

CREATE UNIQUE INDEX "IDX_60b6a84299eeb3f671dfec7693" ON public.insights_by_period USING btree ("periodStart", type, "periodUnit", "metaId");


--
-- Name: IDX_61448d56d61802b5dfde5cdb00; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_61448d56d61802b5dfde5cdb00" ON public.project_relation USING btree ("projectId");


--
-- Name: IDX_62476b94b56d9dc7ed9ed75d3d; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_62476b94b56d9dc7ed9ed75d3d" ON public.dynamic_credential_entry USING btree (subject_id);


--
-- Name: IDX_63d7bbae72c767cf162d459fcc; Type: INDEX; Schema: public; Owner: radar
--

CREATE UNIQUE INDEX "IDX_63d7bbae72c767cf162d459fcc" ON public.user_api_keys USING btree ("userId", label);


--
-- Name: IDX_6edec973a6450990977bb854c3; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_6edec973a6450990977bb854c3" ON public.dynamic_credential_user_entry USING btree ("resolverId");


--
-- Name: IDX_76e212c6867fbaa06bf0decd6f; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_76e212c6867fbaa06bf0decd6f" ON public.instance_ai_messages USING btree ("resourceId");


--
-- Name: IDX_8e4b4774db42f1e6dda3452b2a; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_8e4b4774db42f1e6dda3452b2a" ON public.test_case_execution USING btree ("testRunId");


--
-- Name: IDX_91ee85fa9619dd6776725e117b; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_91ee85fa9619dd6776725e117b" ON public.credential_dependency USING btree ("dependencyType", "dependencyId");


--
-- Name: IDX_92f13cb6bc694227e069447f7b; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_92f13cb6bc694227e069447f7b" ON public.instance_ai_observational_memory USING btree ("lookupKey");


--
-- Name: IDX_97f863fa83c4786f1956508496; Type: INDEX; Schema: public; Owner: radar
--

CREATE UNIQUE INDEX "IDX_97f863fa83c4786f1956508496" ON public.execution_annotations USING btree ("executionId");


--
-- Name: IDX_9c9ee9df586e60bb723234e499; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_9c9ee9df586e60bb723234e499" ON public.dynamic_credential_resolver USING btree (type);


--
-- Name: IDX_UniqueRoleDisplayName; Type: INDEX; Schema: public; Owner: radar
--

CREATE UNIQUE INDEX "IDX_UniqueRoleDisplayName" ON public.role USING btree ("displayName");


--
-- Name: IDX_a3697779b366e131b2bbdae297; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_a3697779b366e131b2bbdae297" ON public.execution_annotation_tags USING btree ("tagId");


--
-- Name: IDX_a36dc616fabc3f736bb82410a2; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_a36dc616fabc3f736bb82410a2" ON public.dynamic_credential_user_entry USING btree ("userId");


--
-- Name: IDX_a371ee6b8e0ebb5635f8baa46d; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_a371ee6b8e0ebb5635f8baa46d" ON public.instance_ai_workflow_snapshots USING btree ("workflowName", status);


--
-- Name: IDX_a4ff2d9b9628ea988fa9e7d0bf; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_a4ff2d9b9628ea988fa9e7d0bf" ON public.workflow_dependency USING btree ("workflowId");


--
-- Name: IDX_a680ac96aae02dc887bbaac512; Type: INDEX; Schema: public; Owner: radar
--

CREATE UNIQUE INDEX "IDX_a680ac96aae02dc887bbaac512" ON public.instance_ai_observational_memory USING btree (scope, "threadId", "resourceId");


--
-- Name: IDX_ae51b54c4bb430cf92f48b623f; Type: INDEX; Schema: public; Owner: radar
--

CREATE UNIQUE INDEX "IDX_ae51b54c4bb430cf92f48b623f" ON public.annotation_tag_entity USING btree (name);


--
-- Name: IDX_bb66e404c35996b0d694617750; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_bb66e404c35996b0d694617750" ON public.role_mapping_rule USING btree (role);


--
-- Name: IDX_c1519757391996eb06064f0e7c; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_c1519757391996eb06064f0e7c" ON public.execution_annotation_tags USING btree ("annotationId");


--
-- Name: IDX_cec8eea3bf49551482ccb4933e; Type: INDEX; Schema: public; Owner: radar
--

CREATE UNIQUE INDEX "IDX_cec8eea3bf49551482ccb4933e" ON public.execution_metadata USING btree ("executionId", key);


--
-- Name: IDX_chat_hub_messages_sessionId; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_chat_hub_messages_sessionId" ON public.chat_hub_messages USING btree ("sessionId");


--
-- Name: IDX_chat_hub_sessions_owner_lastmsg_id; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_chat_hub_sessions_owner_lastmsg_id" ON public.chat_hub_sessions USING btree ("ownerId", "lastMessageAt" DESC, id);


--
-- Name: IDX_credential_dependency_credentialId_dependencyType_dependenc; Type: INDEX; Schema: public; Owner: radar
--

CREATE UNIQUE INDEX "IDX_credential_dependency_credentialId_dependencyType_dependenc" ON public.credential_dependency USING btree ("credentialId", "dependencyType", "dependencyId");


--
-- Name: IDX_d3a2bc880e7a8626802e5474ad; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_d3a2bc880e7a8626802e5474ad" ON public.instance_ai_run_snapshots USING btree ("threadId", "createdAt");


--
-- Name: IDX_d61a12235d268a49af6a3c09c1; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_d61a12235d268a49af6a3c09c1" ON public.dynamic_credential_entry USING btree (resolver_id);


--
-- Name: IDX_d6870d3b6e4c185d33926f423c; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_d6870d3b6e4c185d33926f423c" ON public.test_run USING btree ("workflowId");


--
-- Name: IDX_d926c16c2ad9728cb9a81790c0; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_d926c16c2ad9728cb9a81790c0" ON public.instance_ai_run_snapshots USING btree ("threadId", "messageGroupId");


--
-- Name: IDX_e48a201071ab85d9d09119d640; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_e48a201071ab85d9d09119d640" ON public.workflow_dependency USING btree ("dependencyKey");


--
-- Name: IDX_e7fe1cfda990c14a445937d0b9; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_e7fe1cfda990c14a445937d0b9" ON public.workflow_dependency USING btree ("dependencyType");


--
-- Name: IDX_execution_entity_deletedAt; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_execution_entity_deletedAt" ON public.execution_entity USING btree ("deletedAt");


--
-- Name: IDX_f36dea4d38fe92e0e8f44d5a56; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_f36dea4d38fe92e0e8f44d5a56" ON public.instance_ai_threads USING btree ("resourceId");


--
-- Name: IDX_role_scope_scopeSlug; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_role_scope_scopeSlug" ON public.role_scope USING btree ("scopeSlug");


--
-- Name: IDX_secrets_provider_connection_providerKey; Type: INDEX; Schema: public; Owner: radar
--

CREATE UNIQUE INDEX "IDX_secrets_provider_connection_providerKey" ON public.secrets_provider_connection USING btree ("providerKey");


--
-- Name: IDX_workflow_dependency_publishedVersionId; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_workflow_dependency_publishedVersionId" ON public.workflow_dependency USING btree ("publishedVersionId");


--
-- Name: IDX_workflow_entity_name; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX "IDX_workflow_entity_name" ON public.workflow_entity USING btree (name);


--
-- Name: IDX_workflow_statistics_workflow_name; Type: INDEX; Schema: public; Owner: radar
--

CREATE UNIQUE INDEX "IDX_workflow_statistics_workflow_name" ON public.workflow_statistics USING btree ("workflowId", name);


--
-- Name: idx_07fde106c0b471d8cc80a64fc8; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX idx_07fde106c0b471d8cc80a64fc8 ON public.credentials_entity USING btree (type);


--
-- Name: idx_16f4436789e804e3e1c9eeb240; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX idx_16f4436789e804e3e1c9eeb240 ON public.webhook_entity USING btree ("webhookId", method, "pathLength");


--
-- Name: idx_812eb05f7451ca757fb98444ce; Type: INDEX; Schema: public; Owner: radar
--

CREATE UNIQUE INDEX idx_812eb05f7451ca757fb98444ce ON public.tag_entity USING btree (name);


--
-- Name: idx_applications_job_id; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX idx_applications_job_id ON public.applications USING btree (job_id);


--
-- Name: idx_applications_stage; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX idx_applications_stage ON public.applications USING btree (stage);


--
-- Name: idx_device_tokens_token; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX idx_device_tokens_token ON public.device_tokens USING btree (token);


--
-- Name: idx_execution_entity_stopped_at_status_deleted_at; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX idx_execution_entity_stopped_at_status_deleted_at ON public.execution_entity USING btree ("stoppedAt", status, "deletedAt") WHERE (("stoppedAt" IS NOT NULL) AND ("deletedAt" IS NULL));


--
-- Name: idx_execution_entity_wait_till_status_deleted_at; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX idx_execution_entity_wait_till_status_deleted_at ON public.execution_entity USING btree ("waitTill", status, "deletedAt") WHERE (("waitTill" IS NOT NULL) AND ("deletedAt" IS NULL));


--
-- Name: idx_execution_entity_workflow_id_started_at; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX idx_execution_entity_workflow_id_started_at ON public.execution_entity USING btree ("workflowId", "startedAt") WHERE (("startedAt" IS NOT NULL) AND ("deletedAt" IS NULL));


--
-- Name: idx_opp_applied; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX idx_opp_applied ON public.opportunities USING btree (applied);


--
-- Name: idx_opp_date; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX idx_opp_date ON public.opportunities USING btree (date_found DESC);


--
-- Name: idx_opp_hash; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX idx_opp_hash ON public.opportunities USING btree (job_hash);


--
-- Name: idx_opp_score; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX idx_opp_score ON public.opportunities USING btree (opportunity_score DESC NULLS LAST);


--
-- Name: idx_opp_source; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX idx_opp_source ON public.opportunities USING btree (job_source);


--
-- Name: idx_opp_unscored; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX idx_opp_unscored ON public.opportunities USING btree (id) WHERE (opportunity_score IS NULL);


--
-- Name: idx_workflows_tags_workflow_id; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX idx_workflows_tags_workflow_id ON public.workflows_tags USING btree ("workflowId");


--
-- Name: pk_credentials_entity_id; Type: INDEX; Schema: public; Owner: radar
--

CREATE UNIQUE INDEX pk_credentials_entity_id ON public.credentials_entity USING btree (id);


--
-- Name: pk_tag_entity_id; Type: INDEX; Schema: public; Owner: radar
--

CREATE UNIQUE INDEX pk_tag_entity_id ON public.tag_entity USING btree (id);


--
-- Name: pk_workflow_entity_id; Type: INDEX; Schema: public; Owner: radar
--

CREATE UNIQUE INDEX pk_workflow_entity_id ON public.workflow_entity USING btree (id);


--
-- Name: project_relation_role_idx; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX project_relation_role_idx ON public.project_relation USING btree (role);


--
-- Name: project_relation_role_project_idx; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX project_relation_role_project_idx ON public.project_relation USING btree ("projectId", role);


--
-- Name: user_role_idx; Type: INDEX; Schema: public; Owner: radar
--

CREATE INDEX user_role_idx ON public."user" USING btree ("roleSlug");


--
-- Name: variables_global_key_unique; Type: INDEX; Schema: public; Owner: radar
--

CREATE UNIQUE INDEX variables_global_key_unique ON public.variables USING btree (key) WHERE ("projectId" IS NULL);


--
-- Name: variables_project_key_unique; Type: INDEX; Schema: public; Owner: radar
--

CREATE UNIQUE INDEX variables_project_key_unique ON public.variables USING btree ("projectId", key) WHERE ("projectId" IS NOT NULL);


--
-- Name: opportunities trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: radar
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.opportunities FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: applications update_applications_updated_at; Type: TRIGGER; Schema: public; Owner: radar
--

CREATE TRIGGER update_applications_updated_at BEFORE UPDATE ON public.applications FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: device_tokens update_device_tokens_updated_at; Type: TRIGGER; Schema: public; Owner: radar
--

CREATE TRIGGER update_device_tokens_updated_at BEFORE UPDATE ON public.device_tokens FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: workflow_entity workflow_version_increment; Type: TRIGGER; Schema: public; Owner: radar
--

CREATE TRIGGER workflow_version_increment BEFORE UPDATE ON public.workflow_entity FOR EACH ROW EXECUTE FUNCTION public.increment_workflow_version();


--
-- Name: workflow_builder_session FK_00290cdeee4d4d7db84709be936; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.workflow_builder_session
    ADD CONSTRAINT "FK_00290cdeee4d4d7db84709be936" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- Name: processed_data FK_06a69a7032c97a763c2c7599464; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.processed_data
    ADD CONSTRAINT "FK_06a69a7032c97a763c2c7599464" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: workflow_entity FK_08d6c67b7f722b0039d9d5ed620; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.workflow_entity
    ADD CONSTRAINT "FK_08d6c67b7f722b0039d9d5ed620" FOREIGN KEY ("activeVersionId") REFERENCES public.workflow_history("versionId") ON DELETE RESTRICT;


--
-- Name: project_secrets_provider_access FK_18e5c27d2524b1638b292904e48; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.project_secrets_provider_access
    ADD CONSTRAINT "FK_18e5c27d2524b1638b292904e48" FOREIGN KEY ("secretsProviderConnectionId") REFERENCES public.secrets_provider_connection(id) ON DELETE CASCADE;


--
-- Name: insights_metadata FK_1d8ab99d5861c9388d2dc1cf733; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.insights_metadata
    ADD CONSTRAINT "FK_1d8ab99d5861c9388d2dc1cf733" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE SET NULL;


--
-- Name: workflow_history FK_1e31657f5fe46816c34be7c1b4b; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.workflow_history
    ADD CONSTRAINT "FK_1e31657f5fe46816c34be7c1b4b" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: instance_ai_messages FK_1eeb64cb9d66a927988de759e6e; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.instance_ai_messages
    ADD CONSTRAINT "FK_1eeb64cb9d66a927988de759e6e" FOREIGN KEY ("threadId") REFERENCES public.instance_ai_threads(id) ON DELETE CASCADE;


--
-- Name: chat_hub_messages FK_1f4998c8a7dec9e00a9ab15550e; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "FK_1f4998c8a7dec9e00a9ab15550e" FOREIGN KEY ("revisionOfMessageId") REFERENCES public.chat_hub_messages(id) ON DELETE CASCADE;


--
-- Name: oauth_user_consents FK_21e6c3c2d78a097478fae6aaefa; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.oauth_user_consents
    ADD CONSTRAINT "FK_21e6c3c2d78a097478fae6aaefa" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- Name: insights_metadata FK_2375a1eda085adb16b24615b69c; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.insights_metadata
    ADD CONSTRAINT "FK_2375a1eda085adb16b24615b69c" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE SET NULL;


--
-- Name: chat_hub_messages FK_25c9736e7f769f3a005eef4b372; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "FK_25c9736e7f769f3a005eef4b372" FOREIGN KEY ("retryOfMessageId") REFERENCES public.chat_hub_messages(id) ON DELETE CASCADE;


--
-- Name: chat_hub_agent_tools FK_2b53d796b3dbae91b1a9553c048; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.chat_hub_agent_tools
    ADD CONSTRAINT "FK_2b53d796b3dbae91b1a9553c048" FOREIGN KEY ("agentId") REFERENCES public.chat_hub_agents(id) ON DELETE CASCADE;


--
-- Name: instance_ai_run_snapshots FK_2f63fa21d09d7918f347ddbdf70; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.instance_ai_run_snapshots
    ADD CONSTRAINT "FK_2f63fa21d09d7918f347ddbdf70" FOREIGN KEY ("threadId") REFERENCES public.instance_ai_threads(id) ON DELETE CASCADE;


--
-- Name: execution_metadata FK_31d0b4c93fb85ced26f6005cda3; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.execution_metadata
    ADD CONSTRAINT "FK_31d0b4c93fb85ced26f6005cda3" FOREIGN KEY ("executionId") REFERENCES public.execution_entity(id) ON DELETE CASCADE;


--
-- Name: instance_ai_observational_memory FK_34018c303885cd37093458e6409; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.instance_ai_observational_memory
    ADD CONSTRAINT "FK_34018c303885cd37093458e6409" FOREIGN KEY ("threadId") REFERENCES public.instance_ai_threads(id) ON DELETE SET NULL;


--
-- Name: role_mapping_rule_project FK_35a78869286c65d9330d02b88f5; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.role_mapping_rule_project
    ADD CONSTRAINT "FK_35a78869286c65d9330d02b88f5" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE CASCADE;


--
-- Name: shared_credentials FK_416f66fc846c7c442970c094ccf; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.shared_credentials
    ADD CONSTRAINT "FK_416f66fc846c7c442970c094ccf" FOREIGN KEY ("credentialsId") REFERENCES public.credentials_entity(id) ON DELETE CASCADE;


--
-- Name: variables FK_42f6c766f9f9d2edcc15bdd6e9b; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.variables
    ADD CONSTRAINT "FK_42f6c766f9f9d2edcc15bdd6e9b" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE CASCADE;


--
-- Name: chat_hub_agent_tools FK_43e70f04c53344f82483d0570f6; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.chat_hub_agent_tools
    ADD CONSTRAINT "FK_43e70f04c53344f82483d0570f6" FOREIGN KEY ("toolId") REFERENCES public.chat_hub_tools(id) ON DELETE CASCADE;


--
-- Name: chat_hub_agents FK_441ba2caba11e077ce3fbfa2cd8; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.chat_hub_agents
    ADD CONSTRAINT "FK_441ba2caba11e077ce3fbfa2cd8" FOREIGN KEY ("ownerId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- Name: workflow_published_version FK_5c76fb7ee939fe2530374d3f75a; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.workflow_published_version
    ADD CONSTRAINT "FK_5c76fb7ee939fe2530374d3f75a" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE RESTRICT;


--
-- Name: credential_dependency FK_5ec8e8c8d3539f3696cf73b43bf; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.credential_dependency
    ADD CONSTRAINT "FK_5ec8e8c8d3539f3696cf73b43bf" FOREIGN KEY ("credentialId") REFERENCES public.credentials_entity(id) ON DELETE CASCADE;


--
-- Name: project_relation FK_5f0643f6717905a05164090dde7; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.project_relation
    ADD CONSTRAINT "FK_5f0643f6717905a05164090dde7" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- Name: project_relation FK_61448d56d61802b5dfde5cdb002; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.project_relation
    ADD CONSTRAINT "FK_61448d56d61802b5dfde5cdb002" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE CASCADE;


--
-- Name: insights_by_period FK_6414cfed98daabbfdd61a1cfbc0; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.insights_by_period
    ADD CONSTRAINT "FK_6414cfed98daabbfdd61a1cfbc0" FOREIGN KEY ("metaId") REFERENCES public.insights_metadata("metaId") ON DELETE CASCADE;


--
-- Name: oauth_authorization_codes FK_64d965bd072ea24fb6da55468cd; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.oauth_authorization_codes
    ADD CONSTRAINT "FK_64d965bd072ea24fb6da55468cd" FOREIGN KEY ("clientId") REFERENCES public.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: chat_hub_session_tools FK_6596a328affd8d4967ffb303eee; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.chat_hub_session_tools
    ADD CONSTRAINT "FK_6596a328affd8d4967ffb303eee" FOREIGN KEY ("toolId") REFERENCES public.chat_hub_tools(id) ON DELETE CASCADE;


--
-- Name: chat_hub_messages FK_6afb260449dd7a9b85355d4e0c9; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "FK_6afb260449dd7a9b85355d4e0c9" FOREIGN KEY ("executionId") REFERENCES public.execution_entity(id) ON DELETE SET NULL;


--
-- Name: insights_raw FK_6e2e33741adef2a7c5d66befa4e; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.insights_raw
    ADD CONSTRAINT "FK_6e2e33741adef2a7c5d66befa4e" FOREIGN KEY ("metaId") REFERENCES public.insights_metadata("metaId") ON DELETE CASCADE;


--
-- Name: workflow_publish_history FK_6eab5bd9eedabe9c54bd879fc40; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.workflow_publish_history
    ADD CONSTRAINT "FK_6eab5bd9eedabe9c54bd879fc40" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE SET NULL;


--
-- Name: dynamic_credential_user_entry FK_6edec973a6450990977bb854c38; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.dynamic_credential_user_entry
    ADD CONSTRAINT "FK_6edec973a6450990977bb854c38" FOREIGN KEY ("resolverId") REFERENCES public.dynamic_credential_resolver(id) ON DELETE CASCADE;


--
-- Name: oauth_access_tokens FK_7234a36d8e49a1fa85095328845; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.oauth_access_tokens
    ADD CONSTRAINT "FK_7234a36d8e49a1fa85095328845" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- Name: installed_nodes FK_73f857fc5dce682cef8a99c11dbddbc969618951; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.installed_nodes
    ADD CONSTRAINT "FK_73f857fc5dce682cef8a99c11dbddbc969618951" FOREIGN KEY (package) REFERENCES public.installed_packages("packageName") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: oauth_access_tokens FK_78b26968132b7e5e45b75876481; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.oauth_access_tokens
    ADD CONSTRAINT "FK_78b26968132b7e5e45b75876481" FOREIGN KEY ("clientId") REFERENCES public.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: workflow_builder_session FK_7983c618db48f47bf5a4cc1e1e4; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.workflow_builder_session
    ADD CONSTRAINT "FK_7983c618db48f47bf5a4cc1e1e4" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: chat_hub_sessions FK_7bc13b4c7e6afbfaf9be326c189; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.chat_hub_sessions
    ADD CONSTRAINT "FK_7bc13b4c7e6afbfaf9be326c189" FOREIGN KEY ("credentialId") REFERENCES public.credentials_entity(id) ON DELETE SET NULL;


--
-- Name: folder FK_804ea52f6729e3940498bd54d78; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.folder
    ADD CONSTRAINT "FK_804ea52f6729e3940498bd54d78" FOREIGN KEY ("parentFolderId") REFERENCES public.folder(id) ON DELETE CASCADE;


--
-- Name: shared_credentials FK_812c2852270da1247756e77f5a4; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.shared_credentials
    ADD CONSTRAINT "FK_812c2852270da1247756e77f5a4" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE CASCADE;


--
-- Name: instance_ai_iteration_logs FK_8bfcc6c51fd3d69b1eae8aebd49; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.instance_ai_iteration_logs
    ADD CONSTRAINT "FK_8bfcc6c51fd3d69b1eae8aebd49" FOREIGN KEY ("threadId") REFERENCES public.instance_ai_threads(id) ON DELETE CASCADE;


--
-- Name: test_case_execution FK_8e4b4774db42f1e6dda3452b2af; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.test_case_execution
    ADD CONSTRAINT "FK_8e4b4774db42f1e6dda3452b2af" FOREIGN KEY ("testRunId") REFERENCES public.test_run(id) ON DELETE CASCADE;


--
-- Name: data_table_column FK_930b6e8faaf88294cef23484160; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.data_table_column
    ADD CONSTRAINT "FK_930b6e8faaf88294cef23484160" FOREIGN KEY ("dataTableId") REFERENCES public.data_table(id) ON DELETE CASCADE;


--
-- Name: dynamic_credential_user_entry FK_945ba70b342a066d1306b12ccd2; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.dynamic_credential_user_entry
    ADD CONSTRAINT "FK_945ba70b342a066d1306b12ccd2" FOREIGN KEY ("credentialId") REFERENCES public.credentials_entity(id) ON DELETE CASCADE;


--
-- Name: folder_tag FK_94a60854e06f2897b2e0d39edba; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.folder_tag
    ADD CONSTRAINT "FK_94a60854e06f2897b2e0d39edba" FOREIGN KEY ("folderId") REFERENCES public.folder(id) ON DELETE CASCADE;


--
-- Name: execution_annotations FK_97f863fa83c4786f19565084960; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.execution_annotations
    ADD CONSTRAINT "FK_97f863fa83c4786f19565084960" FOREIGN KEY ("executionId") REFERENCES public.execution_entity(id) ON DELETE CASCADE;


--
-- Name: chat_hub_agents FK_9c61ad497dcbae499c96a6a78ba; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.chat_hub_agents
    ADD CONSTRAINT "FK_9c61ad497dcbae499c96a6a78ba" FOREIGN KEY ("credentialId") REFERENCES public.credentials_entity(id) ON DELETE SET NULL;


--
-- Name: chat_hub_sessions FK_9f9293d9f552496c40e0d1a8f80; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.chat_hub_sessions
    ADD CONSTRAINT "FK_9f9293d9f552496c40e0d1a8f80" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE SET NULL;


--
-- Name: execution_annotation_tags FK_a3697779b366e131b2bbdae2976; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.execution_annotation_tags
    ADD CONSTRAINT "FK_a3697779b366e131b2bbdae2976" FOREIGN KEY ("tagId") REFERENCES public.annotation_tag_entity(id) ON DELETE CASCADE;


--
-- Name: dynamic_credential_user_entry FK_a36dc616fabc3f736bb82410a22; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.dynamic_credential_user_entry
    ADD CONSTRAINT "FK_a36dc616fabc3f736bb82410a22" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- Name: shared_workflow FK_a45ea5f27bcfdc21af9b4188560; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.shared_workflow
    ADD CONSTRAINT "FK_a45ea5f27bcfdc21af9b4188560" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE CASCADE;


--
-- Name: workflow_dependency FK_a4ff2d9b9628ea988fa9e7d0bf8; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.workflow_dependency
    ADD CONSTRAINT "FK_a4ff2d9b9628ea988fa9e7d0bf8" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: oauth_user_consents FK_a651acea2f6c97f8c4514935486; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.oauth_user_consents
    ADD CONSTRAINT "FK_a651acea2f6c97f8c4514935486" FOREIGN KEY ("clientId") REFERENCES public.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: oauth_refresh_tokens FK_a699f3ed9fd0c1b19bc2608ac53; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.oauth_refresh_tokens
    ADD CONSTRAINT "FK_a699f3ed9fd0c1b19bc2608ac53" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- Name: dynamic_credential_entry FK_a6d1dd080958304a47a02952aab; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.dynamic_credential_entry
    ADD CONSTRAINT "FK_a6d1dd080958304a47a02952aab" FOREIGN KEY (credential_id) REFERENCES public.credentials_entity(id) ON DELETE CASCADE;


--
-- Name: folder FK_a8260b0b36939c6247f385b8221; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.folder
    ADD CONSTRAINT "FK_a8260b0b36939c6247f385b8221" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE CASCADE;


--
-- Name: oauth_authorization_codes FK_aa8d3560484944c19bdf79ffa16; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.oauth_authorization_codes
    ADD CONSTRAINT "FK_aa8d3560484944c19bdf79ffa16" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- Name: chat_hub_messages FK_acf8926098f063cdbbad8497fd1; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "FK_acf8926098f063cdbbad8497fd1" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE SET NULL;


--
-- Name: oauth_refresh_tokens FK_b388696ce4d8be7ffbe8d3e4b69; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.oauth_refresh_tokens
    ADD CONSTRAINT "FK_b388696ce4d8be7ffbe8d3e4b69" FOREIGN KEY ("clientId") REFERENCES public.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: workflow_publish_history FK_b4cfbc7556d07f36ca177f5e473; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.workflow_publish_history
    ADD CONSTRAINT "FK_b4cfbc7556d07f36ca177f5e473" FOREIGN KEY ("versionId") REFERENCES public.workflow_history("versionId") ON DELETE CASCADE;


--
-- Name: chat_hub_tools FK_b8030b47af9213f1fd15450fb7f; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.chat_hub_tools
    ADD CONSTRAINT "FK_b8030b47af9213f1fd15450fb7f" FOREIGN KEY ("ownerId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- Name: role_mapping_rule FK_bb66e404c35996b0d6946177501; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.role_mapping_rule
    ADD CONSTRAINT "FK_bb66e404c35996b0d6946177501" FOREIGN KEY (role) REFERENCES public.role(slug) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: project_secrets_provider_access FK_bd264b81209355b543878deedb1; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.project_secrets_provider_access
    ADD CONSTRAINT "FK_bd264b81209355b543878deedb1" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE CASCADE;


--
-- Name: workflow_publish_history FK_c01316f8c2d7101ec4fa9809267; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.workflow_publish_history
    ADD CONSTRAINT "FK_c01316f8c2d7101ec4fa9809267" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: execution_annotation_tags FK_c1519757391996eb06064f0e7c8; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.execution_annotation_tags
    ADD CONSTRAINT "FK_c1519757391996eb06064f0e7c8" FOREIGN KEY ("annotationId") REFERENCES public.execution_annotations(id) ON DELETE CASCADE;


--
-- Name: data_table FK_c2a794257dee48af7c9abf681de; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.data_table
    ADD CONSTRAINT "FK_c2a794257dee48af7c9abf681de" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE CASCADE;


--
-- Name: project_relation FK_c6b99592dc96b0d836d7a21db91; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.project_relation
    ADD CONSTRAINT "FK_c6b99592dc96b0d836d7a21db91" FOREIGN KEY (role) REFERENCES public.role(slug);


--
-- Name: chat_hub_messages FK_chat_hub_messages_agentId; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "FK_chat_hub_messages_agentId" FOREIGN KEY ("agentId") REFERENCES public.chat_hub_agents(id) ON DELETE SET NULL;


--
-- Name: chat_hub_sessions FK_chat_hub_sessions_agentId; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.chat_hub_sessions
    ADD CONSTRAINT "FK_chat_hub_sessions_agentId" FOREIGN KEY ("agentId") REFERENCES public.chat_hub_agents(id) ON DELETE SET NULL;


--
-- Name: dynamic_credential_entry FK_d61a12235d268a49af6a3c09c13; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.dynamic_credential_entry
    ADD CONSTRAINT "FK_d61a12235d268a49af6a3c09c13" FOREIGN KEY (resolver_id) REFERENCES public.dynamic_credential_resolver(id) ON DELETE CASCADE;


--
-- Name: test_run FK_d6870d3b6e4c185d33926f423c8; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.test_run
    ADD CONSTRAINT "FK_d6870d3b6e4c185d33926f423c8" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: shared_workflow FK_daa206a04983d47d0a9c34649ce; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.shared_workflow
    ADD CONSTRAINT "FK_daa206a04983d47d0a9c34649ce" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: folder_tag FK_dc88164176283de80af47621746; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.folder_tag
    ADD CONSTRAINT "FK_dc88164176283de80af47621746" FOREIGN KEY ("tagId") REFERENCES public.tag_entity(id) ON DELETE CASCADE;


--
-- Name: role_mapping_rule_project FK_dd7ce4dfa09e95b36a626bd9de3; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.role_mapping_rule_project
    ADD CONSTRAINT "FK_dd7ce4dfa09e95b36a626bd9de3" FOREIGN KEY ("roleMappingRuleId") REFERENCES public.role_mapping_rule(id) ON DELETE CASCADE;


--
-- Name: workflow_published_version FK_df3428a541b802d6a63ac56e330; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.workflow_published_version
    ADD CONSTRAINT "FK_df3428a541b802d6a63ac56e330" FOREIGN KEY ("publishedVersionId") REFERENCES public.workflow_history("versionId") ON DELETE RESTRICT;


--
-- Name: user_api_keys FK_e131705cbbc8fb589889b02d457; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.user_api_keys
    ADD CONSTRAINT "FK_e131705cbbc8fb589889b02d457" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- Name: chat_hub_messages FK_e22538eb50a71a17954cd7e076c; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "FK_e22538eb50a71a17954cd7e076c" FOREIGN KEY ("sessionId") REFERENCES public.chat_hub_sessions(id) ON DELETE CASCADE;


--
-- Name: test_case_execution FK_e48965fac35d0f5b9e7f51d8c44; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.test_case_execution
    ADD CONSTRAINT "FK_e48965fac35d0f5b9e7f51d8c44" FOREIGN KEY ("executionId") REFERENCES public.execution_entity(id) ON DELETE SET NULL;


--
-- Name: chat_hub_messages FK_e5d1fa722c5a8d38ac204746662; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "FK_e5d1fa722c5a8d38ac204746662" FOREIGN KEY ("previousMessageId") REFERENCES public.chat_hub_messages(id) ON DELETE CASCADE;


--
-- Name: chat_hub_session_tools FK_e649bf1295f4ed8d4299ed290f9; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.chat_hub_session_tools
    ADD CONSTRAINT "FK_e649bf1295f4ed8d4299ed290f9" FOREIGN KEY ("sessionId") REFERENCES public.chat_hub_sessions(id) ON DELETE CASCADE;


--
-- Name: chat_hub_sessions FK_e9ecf8ede7d989fcd18790fe36a; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.chat_hub_sessions
    ADD CONSTRAINT "FK_e9ecf8ede7d989fcd18790fe36a" FOREIGN KEY ("ownerId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- Name: user FK_eaea92ee7bfb9c1b6cd01505d56; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public."user"
    ADD CONSTRAINT "FK_eaea92ee7bfb9c1b6cd01505d56" FOREIGN KEY ("roleSlug") REFERENCES public.role(slug);


--
-- Name: role_scope FK_role; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.role_scope
    ADD CONSTRAINT "FK_role" FOREIGN KEY ("roleSlug") REFERENCES public.role(slug) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: role_scope FK_scope; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.role_scope
    ADD CONSTRAINT "FK_scope" FOREIGN KEY ("scopeSlug") REFERENCES public.scope(slug) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: applications applications_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.opportunities(id) ON DELETE CASCADE;


--
-- Name: auth_identity auth_identity_userId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.auth_identity
    ADD CONSTRAINT "auth_identity_userId_fkey" FOREIGN KEY ("userId") REFERENCES public."user"(id);


--
-- Name: credentials_entity credentials_entity_resolverId_foreign; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.credentials_entity
    ADD CONSTRAINT "credentials_entity_resolverId_foreign" FOREIGN KEY ("resolverId") REFERENCES public.dynamic_credential_resolver(id) ON DELETE SET NULL;


--
-- Name: execution_data execution_data_fk; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.execution_data
    ADD CONSTRAINT execution_data_fk FOREIGN KEY ("executionId") REFERENCES public.execution_entity(id) ON DELETE CASCADE;


--
-- Name: execution_entity fk_execution_entity_workflow_id; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.execution_entity
    ADD CONSTRAINT fk_execution_entity_workflow_id FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: webhook_entity fk_webhook_entity_workflow_id; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.webhook_entity
    ADD CONSTRAINT fk_webhook_entity_workflow_id FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: workflow_entity fk_workflow_parent_folder; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.workflow_entity
    ADD CONSTRAINT fk_workflow_parent_folder FOREIGN KEY ("parentFolderId") REFERENCES public.folder(id) ON DELETE CASCADE;


--
-- Name: workflows_tags fk_workflows_tags_tag_id; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.workflows_tags
    ADD CONSTRAINT fk_workflows_tags_tag_id FOREIGN KEY ("tagId") REFERENCES public.tag_entity(id) ON DELETE CASCADE;


--
-- Name: workflows_tags fk_workflows_tags_workflow_id; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.workflows_tags
    ADD CONSTRAINT fk_workflows_tags_workflow_id FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: project projects_creatorId_foreign; Type: FK CONSTRAINT; Schema: public; Owner: radar
--

ALTER TABLE ONLY public.project
    ADD CONSTRAINT "projects_creatorId_foreign" FOREIGN KEY ("creatorId") REFERENCES public."user"(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

\unrestrict Zm7vmSLDl0TmVl6Di5b3EVQeSOJf2WCt2AJIwQXZvDjReYKtFwcAYC6kQEwIk9f


import { supabase } from "../lib/supabase";

export async function signIn(
  email,
  password
) {
  const {
    data,
    error,
  } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  if (error) {
    throw error;
  }

  return data;
}


export async function signOut() {
  const {
    error,
  } = await supabase.auth.signOut();

  if (error) {
    throw error;
  }
}


export async function getCurrentUser() {
  const {
    data,
    error,
  } = await supabase.auth.getUser();

  if (error) {
    return null;
  }

  return data.user;
}


export async function getCurrentSession() {
  const {
    data,
    error,
  } = await supabase.auth.getSession();

  if (error) {
    return null;
  }

  return data.session;
}


export async function getCurrentProfile() {
  const user =
    await getCurrentUser();

  if (!user) {
    return null;
  }

  const {
    data,
    error,
  } = await supabase
    .from("profiles")
    .select("*")
    .eq("id", user.id)
    .single();

  if (error) {
    throw error;
  }

  return data;
}